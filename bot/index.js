import { Telegraf } from 'telegraf'
import { exec } from 'child_process'
import util from 'util'

const execAsync = util.promisify(exec);

const BOT_TOKEN = process.env.BOT_TOKEN;
const CHAT_ID = parseInt(process.env.CHAT_ID, 10);
const ADMINS = process.env.ADMINS.split(',');

const bot = new Telegraf(BOT_TOKEN)
const { stdout:host } = await execAsync('hostname -i');

async function checkXrConf() {
    try {
        const { stdout } = await execAsync('xr-conf --health');
        return stdout;
    } catch (e) {
        console.log(e);
        return "ERROR"
    }
}
async function getLinks() {
    try {
        const { stdout } = await execAsync('xr-conf --links');
        return stdout;
    } catch (e){
        console.log(e)
        return "Error while searching links"
    }
}
async function healthCheck() {
    return checkXrConf()
}

bot.use((ctx, next) => {
    if (ctx.chat.id !== CHAT_ID) {
        console.log(ctx.chat.id)
        return 
    }
    return next()
})

bot.command('health', async ctx => {
    const ok = await healthCheck()
    const icon = ok.includes('Up') ? '🟢' : '🔴'
    await ctx.reply(`${icon} Proxy is ${ok} on host ${host}`)
})

bot.command('links', async ctx => {
    const links = await getLinks();
    ctx.reply(links)
})

let lastState = true

setInterval(async () => {
    const msg = await healthCheck()
    const ok = msg.includes('Up');

    if (lastState && !ok) {
        bot.telegram.sendMessage(CHAT_ID, `🚨 Proxy is down on host ${host}`)
    }

    if (!lastState && ok) {
        bot.telegram.sendMessage(CHAT_ID, `✅ Proxy is recovered on host ${host}`)
    }

    lastState = ok
}, 60000)

bot.launch()
console.log(`[xray-bot] Started on ${host}`)
