const { randomBytes } = require("crypto");
const { exec } = require("child_process");
const { promisify } = require("util");
const { Telegraf } = require("telegraf");
const { createClient } = require("redis");
const { fetchConfig } = require("./fetch-conf.js");

const TELEGRAM_MESSAGE_LIMIT = 4096;
const DEFAULT_MESSAGE_TTL_MS = 60 * 60 * 1000;
const USERNAME_RE = /^[A-Za-z0-9_-]{1,64}$/;
const HELP_MESSAGE = [
    'Команды управления Xray:',
    '',
    '/help',
    'Показать эту подсказку.',
    '',
    '/health',
    'Проверить, запущен ли Xray и проходит ли Reality/SNI health check.',
    '',
    '/restart',
    'Пересобрать config.json из шаблонов и перезапустить Xray. Нужен после создания/удаления пользователя и ручных правок templates.',
    '',
    '/create_user <username>',
    'Создать пользователя, сгенерировать ему shortId, сохранить в Redis и добавить shortId в XRAY_SHORT_IDS.',
    '',
    '/delete_user <username>',
    'Удалить пользователя из Redis и убрать его shortId из XRAY_SHORT_IDS.',
    '',
    '/users',
    'Показать список пользователей и их shortId.',
    '',
    '/link <username>',
    'Получить VLESS-ссылку пользователя с подставленным sid.',
    '',
    '/links <username>',
    'То же самое, что /link.',
    '',
    '/client_routing',
    'Получить JSON с клиентскими правилами маршрутизации.',
    '',
    '/add_sni <hostname>',
    'Добавить hostname в список SNI-кандидатов для Reality fallback.',
    '',
    '/sni_list',
    'Показать текущий список SNI-кандидатов.',
    '',
    '/slave_health',
    'Проверить slave через SSH с master-сервера.',
    '',
    '/slave_start',
    'Запустить Xray на slave через SSH.',
    '',
    '/slave_stop',
    'Остановить Xray на slave через SSH.',
    '',
    '/slave_restart',
    'Перезапустить Xray на slave через SSH.'
].join('\n');

function deleteTelegramMessages(telegram, messages) {
    for (const msg of messages) {
        telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
    }
}

function scheduleTelegramMessagesDeletion(telegram, messages, ttlMs = DEFAULT_MESSAGE_TTL_MS) {
    setTimeout(() => deleteTelegramMessages(telegram, messages), ttlMs);
}

async function replyTemporaryText(ctx, text, ttlMs = DEFAULT_MESSAGE_TTL_MS) {
    const messages = [];
    for (let offset = 0; offset < text.length; offset += TELEGRAM_MESSAGE_LIMIT) {
        messages.push(await ctx.reply(text.slice(offset, offset + TELEGRAM_MESSAGE_LIMIT)));
    }

    scheduleTelegramMessagesDeletion(ctx.telegram, messages, ttlMs);
    return messages;
}

async function sendTemporaryText(telegram, chatId, text, ttlMs = DEFAULT_MESSAGE_TTL_MS) {
    const messages = [];
    for (let offset = 0; offset < text.length; offset += TELEGRAM_MESSAGE_LIMIT) {
        messages.push(await telegram.sendMessage(chatId, text.slice(offset, offset + TELEGRAM_MESSAGE_LIMIT)));
    }

    scheduleTelegramMessagesDeletion(telegram, messages, ttlMs);
    return messages;
}

function parseCommandArg(ctx) {
    return ctx.message.text.split(/\s+/)[1];
}

function isValidUsername(username) {
    return USERNAME_RE.test(username);
}

function generateShortId() {
    return randomBytes(4).toString("hex");
}

function addSidToLink(link, sid) {
    try {
        const url = new URL(link);
        url.searchParams.set("sid", sid);
        return url.toString();
    } catch (e) {
        return link;
    }
}

function addSidToLinks(body, sid) {
    return body
        .split(/\r?\n/)
        .map(line => {
            const trimmed = line.trim();
            return trimmed ? addSidToLink(trimmed, sid) : line;
        })
        .join("\n");
}

async function start() {
    const BOT_TOKEN = process.env.BOT_TOKEN;
    const CHAT_ID = parseInt(process.env.CHAT_ID, 10);
    const ADMINS = process.env.ADMINS ? process.env.ADMINS.split(',') : [];
    const REDIS_URL = process.env.REDIS_URL || "redis://127.0.0.1:6379";
    const REDIS_USERS_KEY = process.env.REDIS_USERS_KEY || "xray:users";

    const execAsync = promisify(exec);
    const { stdout: host} = await execAsync('hostname -i')
    const bot = new Telegraf(BOT_TOKEN);
    const redis = createClient({ url: REDIS_URL });

    redis.on("error", err => {
        console.error("[xray-bot] Redis error:", err);
    });

    await redis.connect();

    bot.use(async (ctx, next) => {
        if (ctx.chat && ctx.chat.id && ctx.chat.id !== CHAT_ID) {
            console.log(ctx.chat.id)
            return 
        }
        try {
            await ctx.deleteMessage();
        } catch (e) {
            // молча игнорируем — нет прав или не удалось
        }
        return next()
    });

    bot.command('health', async ctx => {
        const { ok, body } = await fetchConfig('/health');
        const icon = ok ? '🟢' : '🔴';
        await replyTemporaryText(ctx, `${icon} Proxy is ${ok ? 'up' : 'down'} on host ${host}.\n ${body}`);
    });

    bot.command('help', async ctx => {
        await replyTemporaryText(ctx, HELP_MESSAGE);
    });

    bot.command('create_user', async ctx => {
        const username = parseCommandArg(ctx);
        if (!username || !isValidUsername(username)) {
            await replyTemporaryText(ctx, 'Usage: /create_user username\nAllowed: latin letters, digits, _ and -');
            return;
        }

        const existingId = await redis.hGet(REDIS_USERS_KEY, username);
        if (existingId) {
            await replyTemporaryText(ctx, `User already exists: ${username}\nid: ${existingId}`);
            return;
        }

        const id = generateShortId();
        await redis.hSet(REDIS_USERS_KEY, username, id);

        const addShortId = await fetchConfig(`/short-ids/add?short_id=${encodeURIComponent(id)}`);
        if (!addShortId.ok) {
            await redis.hDel(REDIS_USERS_KEY, username);
            await replyTemporaryText(ctx, `Failed to register short id for Xray:\n${addShortId.body}`);
            return;
        }

        await replyTemporaryText(ctx, `User created: ${username}\nid: ${id}\nRun /restart to apply it in Xray.`);
    });

    bot.command('delete_user', async ctx => {
        const username = parseCommandArg(ctx);
        if (!username || !isValidUsername(username)) {
            await replyTemporaryText(ctx, 'Usage: /delete_user username');
            return;
        }

        const id = await redis.hGet(REDIS_USERS_KEY, username);
        if (!id) {
            await replyTemporaryText(ctx, `User not found: ${username}`);
            return;
        }

        const removeShortId = await fetchConfig(`/short-ids/remove?short_id=${encodeURIComponent(id)}`);
        if (!removeShortId.ok) {
            await replyTemporaryText(ctx, `Failed to remove short id from Xray:\n${removeShortId.body}`);
            return;
        }

        await redis.hDel(REDIS_USERS_KEY, username);
        await replyTemporaryText(ctx, `User deleted: ${username}\nid: ${id}\nRun /restart to apply it in Xray.`);
    });

    bot.command('users', async ctx => {
        const users = await redis.hGetAll(REDIS_USERS_KEY);
        const entries = Object.entries(users).sort(([a], [b]) => a.localeCompare(b));

        if (entries.length === 0) {
            await replyTemporaryText(ctx, 'Users list is empty');
            return;
        }

        const message = [
            'Users:',
            '',
            ...entries.map(([username, id]) => `${username}: ${id}`)
        ].join('\n');

        await replyTemporaryText(ctx, message);
    });

    async function sendUserLink(ctx) {
        const username = parseCommandArg(ctx);
        if (!username || !isValidUsername(username)) {
            await replyTemporaryText(ctx, 'Usage: /link username');
            return;
        }

        const sid = await redis.hGet(REDIS_USERS_KEY, username);
        if (!sid) {
            await replyTemporaryText(ctx, `User not found: ${username}`);
            return;
        }

        const { ok, body } = await fetchConfig('/links');
        const message = ok ? addSidToLinks(body, sid) : `🔴 Failed to fetch link:\n${body}`;
        await replyTemporaryText(ctx, message);
    }

    bot.command('link', sendUserLink);
    bot.command('links', sendUserLink);

    bot.command('client_routing', async ctx => {
        const { ok, body } = await fetchConfig('/client-routing');
        const message = ok ? body : `🔴 Failed to fetch client routing:\n${body}`;
        await replyTemporaryText(ctx, message);
    });

    bot.command('sni_list', async ctx => {
        const { ok, body } = await fetchConfig('/sni/list');
        await replyTemporaryText(ctx, `${ok ? '🟢' : '🔴'} SNI candidates:\n${body || 'empty'}`);
    });

    bot.command('add_sni', async ctx => {
        const candidate = ctx.message.text.split(/\s+/)[1];
        if (!candidate) {
            await replyTemporaryText(ctx, 'Usage: /add_sni example.com');
            return;
        }

        const { ok, body } = await fetchConfig(`/sni/add?sni=${encodeURIComponent(candidate)}`);
        await replyTemporaryText(ctx, `${ok ? '🟢' : '🔴'} ${body}`);
    });

    bot.command('restart', async ctx => {
        const stop = await fetchConfig('/stop');
        const start = await fetchConfig('/start');
        const message = `${stop.ok && start.ok ? '🟢 Restart success!' : '🔴 Restart fail!'}\n${stop.body}\n${start.body}`;
        await replyTemporaryText(ctx, message);
    });

    async function slaveCommand(ctx, action) {
        const { ok, body } = await fetchConfig(`/slave/${action}`);
        const icon = ok ? '🟢' : '🔴';
        const message = `${icon} Slave ${action}: ${ok ? 'ok' : 'failed'}\n${body}`;
        await replyTemporaryText(ctx, message);
    }

    bot.command('slave_health', async ctx => slaveCommand(ctx, 'health'));
    bot.command('slave_start', async ctx => slaveCommand(ctx, 'start'));
    bot.command('slave_stop', async ctx => slaveCommand(ctx, 'stop'));
    bot.command('slave_restart', async ctx => slaveCommand(ctx, 'restart'));

    bot.on('text', async (ctx, next) => {
        const text = ctx.message?.text || '';
        if (text.startsWith('/')) {
            const command = text.split(/\s+/)[0];
            await replyTemporaryText(ctx, `Unknown command: ${command}\nUse /help to see available commands.`);
            return;
        }

        return next();
    });

    let lastState = true
    let lastmsg;
    setInterval(async () => {
        const { ok, body } = await fetchConfig('/health')
        if (lastState && !ok) {
            lastmsg = await sendTemporaryText(bot.telegram, CHAT_ID, `🔴 Proxy is down on host ${host}.\n ${body}`);
        }
        if (!lastState && ok) {
            if (lastmsg) {
                deleteTelegramMessages(bot.telegram, lastmsg);
            }
            await sendTemporaryText(bot.telegram, CHAT_ID, `🟢 Proxy is recovered on host ${host}.\n ${body}`);
        }
        lastState = ok
    }, 60000);

    bot.launch();
    console.log(`[xray-bot] Started on ${host}`);
}

start();
