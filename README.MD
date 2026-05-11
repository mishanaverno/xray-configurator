# Xray Configurator

Проект поднимает Xray Reality-сервер, локальный configurator API и Telegram-бота для управления SNI, мониторингом и ссылками подключения.

Состав:

- `configurator` - контейнер с Xray, nginx, шаблонами конфигурации и локальным HTTP API.
- `bot` - Telegram-бот, который ходит в configurator API.
- `utils/xr-conf.sh` - CLI-утилита для ручного управления сервисом с хоста.

## Требования

На сервере нужны:

- Docker;
- открытый TCP порт `443`
- Telegram bot token;
- Telegram chat id, из которого разрешено управлять ботом.

Примеры ниже используют host network. Так проще связать bot и configurator через `127.0.0.1`.

## Установка CLI-утилиты

Установить `xr-conf`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/utils/install.sh)"
```

Если нужно сразу указать локальный базовый путь для данных сервиса:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/utils/install.sh)" _ /usr/local/share/xray
```

Этот путь сохраняется внутри установленного `xr-conf` в переменной `LOCAL`. При запуске `xr-conf` сам создаст нужные директории:

```text
/usr/local/share/xray/conf
/usr/local/share/xray/bot
/usr/local/share/xray/bot-data
```

Если `~/.local/bin` не в `PATH`, добавьте:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Сборка образов

Из корня репозитория:

```bash
docker build -t xray-conf:latest ./configurator
docker build -t xray-bot:latest ./bot
```

То же самое через Makefile:

```bash
make build-conf
make build-bot
```

## Запуск configurator

Запустите configurator:

```bash
xr-conf --up-conf
```

`xr-conf --up-conf` не принимает имя preset'а. Контейнер всегда использует встроенный шаблон из `configurator/preset`.

Configurator поднимет:

- nginx stream proxy на `:443`;
- Xray на `127.0.0.1:8443`;
- локальный API на `127.0.0.1:8080`.

При первом запуске будут созданы:

```text
/usr/local/share/xray/conf/secrets.env
/usr/local/share/xray/conf/templates/
/usr/local/share/xray/conf/geosite.dat
/usr/local/share/xray/conf/geoip.dat
```

Проверить состояние:

```bash
xr-conf --health-xray
```

Запустить Xray, если он еще не запущен:

```bash
xr-conf --start-xray
```

## Настройка configurator

Основной файл настроек:

```text
/usr/local/share/xray/conf/templates/variables.env
```

Пример:

```env
XRAY_LOG_LEVEL=warning
XRAY_REALITY=google.com
LINK1_TAG=VLESS_CONF
```

Что важно:

- `XRAY_REALITY` - SNI/Reality destination.
- `LINK1_TAG` - подпись ссылки в `link.txt`.

После ручного изменения templates нужно перезапустить Xray:

```bash
xr-conf --restart-xray
```

## SNI

Список кандидатов:

```text
/usr/local/share/xray/conf/templates/sni_list
```

Добавить SNI через CLI:

```bash
xr-conf --add-sni www.microsoft.com
```

Посмотреть список:

```bash
xr-conf --list-sni
```

При старте с preset `reality` configurator проверяет текущий `XRAY_REALITY` через TLS 1.3. Если он не работает, будет выбран первый рабочий кандидат из `sni_list`.

## Альтернативные presets

В корневой директории `presets/` лежат альтернативные шаблоны. Они не подключаются к уже собранному контейнеру автоматически.
Чтобы собрать образ с другим шаблоном, перенесите нужный preset в `configurator/preset` до сборки configurator.

### Reality + xHTTP slave

Preset `reality_xhttp_slave` - это клон `reality` с дополнительным outbound `xhttp_slave`.
Клиенты подключаются к нему так же, как к обычному Reality-серверу, а сам сервер отправляет российский сегмент на отдельный xHTTP slave.

Схема:

```text
client -> Reality server -> direct/warp
client -> Reality server -> xHTTP slave -> RU internet
```

В `variables.env` основного сервера задайте параметры slave:

```env
SLAVE_HOST=slave.example.com
SLAVE_PORT=443
SLAVE_SERVER_NAME=slave.local
SLAVE_PATH=/xhttp-slave
SLAVE_UUID=...
SLAVE_SSH_HOST=slave.example.com
SLAVE_SSH_USER=root
SLAVE_SSH_PORT=22
```

`SLAVE_UUID` должен совпадать с `XRAY_UUID` на slave-сервере.
`SLAVE_PORT` должен совпадать с публичным портом slave-сервера.
`SLAVE_HOST` может быть IP slave VPS, а `SLAVE_SERVER_NAME` должен совпадать с `HOST` на slave. В preset включен `allowInsecure: true`, поэтому self-signed TLS подходит для межсерверного туннеля.
Routing в этом preset оставляет ChatGPT/OpenAI в outbound `warp`, а `domain:ru`, `geosite:category-gov-ru` и `geoip:ru` отправляет в outbound `xhttp_slave`.

Для управления slave через бота основной сервер использует отдельный SSH key. В preset `reality_xhttp_slave` configurator генерирует его автоматически при старте контейнера.
Посмотреть public key:

```bash
xr-conf --slave-pubkey
```

SSH-подключение к slave можно записать в `variables.env` командой:

```bash
xr-conf --set-slave-ssh slave.example.com root 22
```

Добавьте public key на slave-сервер в `~/.ssh/authorized_keys` пользователя `SLAVE_SSH_USER`.
После этого основной configurator сможет выполнять на slave локальные API-команды через SSH:

```bash
xr-conf --slave-health
xr-conf --slave-start
xr-conf --slave-stop
xr-conf --slave-restart
```

### xHTTP slave

Preset `xhttp_slave` нужен для отдельного slave-сервера, который принимает трафик от основного Reality-сервера через VLESS + xHTTP + TLS.
Основной Reality-сервер должен отправлять сюда только нужный сегмент, например RU-зону. slave не ходит в Cloudflare WARP: все принятые запросы выпускаются через `freedom`, кроме явно заблокированного bittorrent.

Схема:

```text
client -> Reality server -> xHTTP slave -> direct internet
```

В отличие от `reality`, preset `xhttp_slave` не содержит клиентские файлы:

- `client_routing.json`;
- `link.txt`;
- `sni_list`;
- Reality inbound/link templates.

Рабочие файлы preset'а:

```text
presets/xhttp_slave/inbound.json
presets/xhttp_slave/outbound.json
presets/xhttp_slave/routing.json
presets/xhttp_slave/variables.env
```

В `variables.env` slave-сервера задайте:

```env
HOST=slave.local
SLAVE_PATH=/xhttp-slave
TLS_CERT_FILE=/usr/share/xray/certs/fullchain.pem
TLS_KEY_FILE=/usr/share/xray/certs/privkey.pem
```

`XRAY_UUID` генерируется configurator'ом автоматически и сохраняется в `secrets.env`. Посмотреть его можно командой:

```bash
docker exec xray-conf sh -lc '. /usr/share/xray/secrets.env; echo "$XRAY_UUID"'
```

Если сертификата по путям `TLS_CERT_FILE` и `TLS_KEY_FILE` нет, configurator автоматически сгенерирует self-signed сертификат при `xr-conf --start-xray`.
Если нужен свой сертификат, положите `fullchain.pem` и `privkey.pem` в `/usr/local/share/xray/conf/certs/` до старта Xray.
На slave-сервере снаружи должен быть открыт публичный порт, который принимает TLS и прокидывает поток в локальный Xray inbound `127.0.0.1:1050`.
Если Xray при старте ругается на `network: xhttp`, обновите образ Xray/configurator до версии с поддержкой xHTTP.

Поменять порт slave для основного сервера можно так:

```bash
# на основном reality_xhttp_slave сервере указать новый порт slave
xr-conf --set-reality-slave-port 9443
```

Применить изменения:

```bash
xr-conf --restart-xray
```

## Настройка Telegram-бота

Создайте env-файл, например `/usr/local/share/xray/bot.env`:

```env
BOT_TOKEN=123456:telegram-bot-token
CHAT_ID=123456789
XRAY_API_BASE=http://127.0.0.1:8080
```

`CHAT_ID` - id Telegram-чата, из которого разрешено управлять ботом. Сообщения из других чатов бот игнорирует.

Запуск:

```bash
xr-conf --up-bot
```

Проверить логи:

```bash
docker logs -f xray-bot
```

## Резервный MTProto proxy для Telegram

Если Xray сломан, Telegram может быть недоступен, и ботом не получится управлять. Для аварийного доступа можно поднять отдельный MTProto proxy на порту `8443`:

```bash
xr-conf --up-mtproto
```

Получить ссылку для Telegram:

```bash
xr-conf --mtproto-logs
```

В логах будет ссылка вида:

```text
tg://proxy?server=SERVER_IP&port=8443&secret=...
```

Остановить MTProto proxy:

```bash
xr-conf --down-mtproto
```

Если нужен другой порт:

```bash
MTPROTO_PORT=9443 xr-conf --up-mtproto
```

## Команды бота

- `/help` - показать подсказку со всеми командами.
- `/health` - проверить состояние Xray и Reality/SNI.
- `/restart` - пересобрать config и перезапустить Xray.
- `/links` - получить VLESS-ссылки; каждая строка отправляется отдельным сообщением.
- `/client_routing` - получить клиентские routing-правила, если текущий preset их предоставляет.
- `/add_sni <hostname>` - добавить SNI-кандидат для Reality fallback.
- `/sni_list` - показать список SNI-кандидатов, если текущий preset использует SNI.
- `/slave_health` - проверить slave через SSH.
- `/slave_start` - запустить Xray на slave через SSH.
- `/slave_stop` - остановить Xray на slave через SSH.
- `/slave_restart` - перезапустить Xray на slave через SSH.

## Как использовать сервис

Обычный сценарий:

1. Запустить configurator.
2. Проверить `/health`.
3. Запустить Xray через `/start` или `/restart`.
4. Запустить Telegram-бота.
5. Получить ссылки через `/links`.
6. Импортировать нужную ссылку в клиент.

Для клиентских routing-правил:

```text
/client_routing
```

Бот вернет содержимое `client_routing.json`.

## Полезные команды

Configurator:

```bash
xr-conf --health-xray
xr-conf --start-xray
xr-conf --stop-xray
xr-conf --restart-xray
xr-conf --links
xr-conf --slave-pubkey
xr-conf --set-slave-ssh slave.example.com root 22
xr-conf --set-reality-slave-port 9443
xr-conf --slave-health
xr-conf --slave-start
xr-conf --slave-stop
xr-conf --slave-restart
xr-conf --up-mtproto
xr-conf --mtproto-logs
xr-conf --down-mtproto
xr-conf --list-sni
xr-conf --add-sni www.microsoft.com
```

Docker:

```bash
docker logs -f xray-conf
docker logs -f xray-bot
docker restart xray-conf
docker restart xray-bot
```

## Важные замечания

- `secrets.env` содержит приватный Reality key. Не публикуйте этот файл.
- После изменения SNI или templates нужен restart Xray.
- Configurator API рассчитан на локальный доступ. Не публикуйте порт `8080` наружу.
- Контейнер configurator должен иметь право слушать внешний proxy-порт `443`.
