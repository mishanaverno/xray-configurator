const { exec } = require("child_process");
const { promisify } = require("util");
const { Telegraf } = require("telegraf");
const { fetchConfig } = require("./fetch-conf.js");

const TELEGRAM_MESSAGE_LIMIT = 4096;
const DEFAULT_MESSAGE_TTL_MS = 60 * 60 * 1000;
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
    'Пересобрать config.json из шаблонов и перезапустить Xray. Нужен после ручных правок preset.',
    '',
    '/links',
    'Получить VLESS-ссылки. Каждая строка отправляется отдельным сообщением.',
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

async function start() {
    const BOT_TOKEN = process.env.BOT_TOKEN;
    const CHAT_ID = parseInt(process.env.CHAT_ID, 10);

    const execAsync = promisify(exec);
    const { stdout: host} = await execAsync('hostname -i')
    const bot = new Telegraf(BOT_TOKEN);

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

    async function sendLinks(ctx) {
        const { ok, body } = await fetchConfig('/links');
        if (!ok) {
            await replyTemporaryText(ctx, `🔴 Failed to fetch links:\n${body}`);
            return;
        }

        const lines = body
            .split(/\r?\n/)
            .map(line => line.trim())
            .filter(Boolean);

        if (lines.length === 0) {
            await replyTemporaryText(ctx, 'Links list is empty');
            return;
        }

        for (const line of lines) {
            await replyTemporaryText(ctx, line);
        }
    }

    bot.command('links', sendLinks);

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
