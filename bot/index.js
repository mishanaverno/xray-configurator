require("dotenv").config();
const { Telegraf } = require("telegraf");
const { fetchConfig } = require("./fetch-conf.js");

import util from 'util'

const execAsync = util.promisify(exec);

const BOT_TOKEN = process.env.BOT_TOKEN;
const CHAT_ID = parseInt(process.env.CHAT_ID, 10);
const ADMINS = process.env.ADMINS.split(',');

const { stdout:host } = await execAsync('hostname -i');

const bot = new Telegraf(BOT_TOKEN);

bot.use((ctx, next) => {
    if (ctx.chat.id !== CHAT_ID) {
        console.log(ctx.chat.id)
        return 
    }
    return next()
});

bot.command('health', async ctx => {
    const { ok, body } = await fetchConfig('/health');
    const icon = ok ? '🟢' : '🔴';
    await ctx.reply(`${icon} Proxy is ${ok} on host ${host}.\n ${body}`);
});

bot.command('links', async ctx => {
    const { body } = await fetchConfig('/links');
    ctx.reply(body);
});

bot.command('restart', async ctx => {
    const stop = await fetchConfig('/stop');
    const start = await fetchConfig('/start');
    const message = `${stop.ok && start.ok ? '🟢 Restart success!' : '🔴 Restart fail!'}\n${stop.body}\n${start.body}`;
    ctx.reply(message)
});
let lastState = true

setInterval(async () => {
    const { ok, body } = await fetchConfig('/health')
    if (lastState && !ok) {
        bot.telegram.sendMessage(CHAT_ID, `🔴 Proxy is down on host ${host}.\n ${body}`)
    }
    if (!lastState && ok) {
        bot.telegram.sendMessage(CHAT_ID, `🟢 Proxy is recovered on host ${host}.\n ${body}`)
    }
    lastState = ok
}, 60000);

bot.launch()
console.log(`[xray-bot] Started on ${host}`)
