const { exec } = require("child_process");
const { promisify } = require("util");
const { Telegraf } = require("telegraf");
const { fetchConfig } = require("./fetch-conf.js");

const TELEGRAM_MESSAGE_LIMIT = 4096;

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

async function start() {
    const BOT_TOKEN = process.env.BOT_TOKEN;
    const CHAT_ID = parseInt(process.env.CHAT_ID, 10);
    const ADMINS = process.env.ADMINS ? process.env.ADMINS.split(',') : [];

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
        const msg = await ctx.reply(`${icon} Proxy is ${ok ? 'up' : 'down'} on host ${host}.\n ${body}`);
        setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
        }, 10000);
    });

    bot.command('links', async ctx => {
        const { body } = await fetchConfig('/links');
        const msg = await ctx.reply(body);
        setTimeout(() => {
        ctx.telegram.deleteMessage(msg.chat.id, msg.message_id)
            .catch(() => {});
        }, 60000);
    });

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
