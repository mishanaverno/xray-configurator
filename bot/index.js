const { randomBytes } = require("crypto");
const { exec } = require("child_process");
const { promisify } = require("util");
const { Telegraf } = require("telegraf");
const { createClient } = require("redis");
const { fetchConfig } = require("./fetch-conf.js");

const TELEGRAM_MESSAGE_LIMIT = 4096;
const USERNAME_RE = /^[A-Za-z0-9_-]{1,64}$/;

async function replyLongText(ctx, text, ttlMs) {
    const messages = [];
    for (let offset = 0; offset < text.length; offset += TELEGRAM_MESSAGE_LIMIT) {
        messages.push(await ctx.reply(text.slice(offset, offset + TELEGRAM_MESSAGE_LIMIT)));
    }

    setTimeout(() => {
        for (const msg of messages) {
            ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
                .catch(() => {});
        }
    }, ttlMs);
}

async function replyTemporary(ctx, text, ttlMs) {
    const msg = await ctx.reply(text);
    setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
    }, ttlMs);
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
        const msg = await ctx.reply(`${icon} Proxy is ${ok ? 'up' : 'down'} on host ${host}.\n ${body}`);
        setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
        }, 10000);
    });

    bot.command('create_user', async ctx => {
        const username = parseCommandArg(ctx);
        if (!username || !isValidUsername(username)) {
            await replyTemporary(ctx, 'Usage: /create_user username\nAllowed: latin letters, digits, _ and -', 10000);
            return;
        }

        const existingId = await redis.hGet(REDIS_USERS_KEY, username);
        if (existingId) {
            await replyTemporary(ctx, `User already exists: ${username}\nid: ${existingId}`, 60000);
            return;
        }

        const id = generateShortId();
        await redis.hSet(REDIS_USERS_KEY, username, id);

        const addShortId = await fetchConfig(`/short-ids/add?short_id=${encodeURIComponent(id)}`);
        if (!addShortId.ok) {
            await redis.hDel(REDIS_USERS_KEY, username);
            await replyTemporary(ctx, `Failed to register short id for Xray:\n${addShortId.body}`, 10000);
            return;
        }

        await replyTemporary(ctx, `User created: ${username}\nid: ${id}\nRun /restart to apply it in Xray.`, 60000);
    });

    bot.command('delete_user', async ctx => {
        const username = parseCommandArg(ctx);
        if (!username || !isValidUsername(username)) {
            await replyTemporary(ctx, 'Usage: /delete_user username', 10000);
            return;
        }

        const id = await redis.hGet(REDIS_USERS_KEY, username);
        if (!id) {
            await replyTemporary(ctx, `User not found: ${username}`, 10000);
            return;
        }

        const removeShortId = await fetchConfig(`/short-ids/remove?short_id=${encodeURIComponent(id)}`);
        if (!removeShortId.ok) {
            await replyTemporary(ctx, `Failed to remove short id from Xray:\n${removeShortId.body}`, 10000);
            return;
        }

        await redis.hDel(REDIS_USERS_KEY, username);
        await replyTemporary(ctx, `User deleted: ${username}\nid: ${id}\nRun /restart to apply it in Xray.`, 60000);
    });

    async function sendUserLink(ctx) {
        const username = parseCommandArg(ctx);
        if (!username || !isValidUsername(username)) {
            await replyTemporary(ctx, 'Usage: /link username', 10000);
            return;
        }

        const sid = await redis.hGet(REDIS_USERS_KEY, username);
        if (!sid) {
            await replyTemporary(ctx, `User not found: ${username}`, 10000);
            return;
        }

        const { ok, body } = await fetchConfig('/links');
        const message = ok ? addSidToLinks(body, sid) : `🔴 Failed to fetch link:\n${body}`;
        await replyLongText(ctx, message, 60000);
    }

    bot.command('link', sendUserLink);
    bot.command('links', sendUserLink);

    bot.command('client_routing', async ctx => {
        const { ok, body } = await fetchConfig('/client-routing');
        const message = ok ? body : `🔴 Failed to fetch client routing:\n${body}`;
        await replyLongText(ctx, message, 60000);
    });

    bot.command('sni_list', async ctx => {
        const { ok, body } = await fetchConfig('/sni/list');
        const msg = await ctx.reply(`${ok ? '🟢' : '🔴'} SNI candidates:\n${body || 'empty'}`);
        setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
        }, 60000);
    });

    bot.command('add_sni', async ctx => {
        const candidate = ctx.message.text.split(/\s+/)[1];
        if (!candidate) {
            const msg = await ctx.reply('Usage: /add_sni example.com');
            setTimeout(() => {
            ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
                .catch(() => {});
            }, 10000);
            return;
        }

        const { ok, body } = await fetchConfig(`/sni/add?sni=${encodeURIComponent(candidate)}`);
        const msg = await ctx.reply(`${ok ? '🟢' : '🔴'} ${body}`);
        setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
        }, 10000);
    });

    bot.command('restart', async ctx => {
        const stop = await fetchConfig('/stop');
        const start = await fetchConfig('/start');
        const message = `${stop.ok && start.ok ? '🟢 Restart success!' : '🔴 Restart fail!'}\n${stop.body}\n${start.body}`;
        const msg = await ctx.reply(message)
        setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
        }, 10000);
    });
    let lastState = true
    let lastmsg;
    setInterval(async () => {
        const { ok, body } = await fetchConfig('/health')
        if (lastState && !ok) {
            lastmsg = await bot.telegram.sendMessage(CHAT_ID, `🔴 Proxy is down on host ${host}.\n ${body}`);
        }
        if (!lastState && ok) {
            bot.telegram.deleteMessage(lastmsg.chat.id, lastmsg.message_id);
            const msg = await bot.telegram.sendMessage(CHAT_ID, `🟢 Proxy is recovered on host ${host}.\n ${body}`);
            setTimeout(() => {
                bot.telegram.deleteMessage(msg.chat.id, msg.message_id)
                .catch(() => {});
            }, 600000);
        }
        lastState = ok
    }, 60000);

    bot.launch();
    console.log(`[xray-bot] Started on ${host}`);
}

start();
