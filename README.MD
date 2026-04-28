# Xray Configurator

Проект поднимает Xray Reality-сервер, локальный configurator API и Telegram-бота для управления пользователями, SNI и ссылками подключения.

Состав:

- `configurator` - контейнер с Xray, nginx, шаблонами конфигурации и локальным HTTP API.
- `bot` - Telegram-бот со встроенным Redis, который ходит в configurator API и хранит пользователей.
- `utils/xr-conf.sh` - CLI-утилита для ручного управления сервисом с хоста.

## Требования

На сервере нужны:

- Docker;
- открытый TCP порт `443`;
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
XRAY_SHORT_IDS='[""]'
LINK1_TAG=VLESS_CONF
```

Что важно:

- `XRAY_REALITY` - SNI/Reality destination.
- `XRAY_SHORT_IDS` - JSON-массив shortId для пользователей.
- `XRAY_SHORT_IDS='[""]'` означает режим без `sid`; после создания пользователей бот заменит это на реальные id.

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

При старте Xray configurator проверяет текущий `XRAY_REALITY` через TLS 1.3. Если он не работает, будет выбран первый рабочий кандидат из `sni_list`.

## Настройка Telegram-бота

Создайте env-файл, например `/usr/local/share/xray/bot.env`:

```env
BOT_TOKEN=123456:telegram-bot-token
CHAT_ID=123456789
XRAY_API_BASE=http://127.0.0.1:8080
REDIS_USERS_KEY=xray:users
```

`CHAT_ID` - id Telegram-чата, из которого разрешено управлять ботом. Сообщения из других чатов бот игнорирует.

Redis запускается внутри bot-контейнера. Его данные лежат в `/data`, поэтому для сохранения пользователей между перезапусками нужно подключить volume.
`xr-conf --up-bot` подключит `/usr/local/share/xray/bot-data:/data` автоматически.

Запуск:

```bash
xr-conf --up-bot
```

Проверить логи:

```bash
docker logs -f xray-bot
```

## Создание пользователя

В Telegram:

```text
/create_user alice
```

Бот:

1. Генерирует Reality shortId длиной 8 hex-символов.
2. Сохраняет `alice -> shortId` в Redis.
3. Добавляет shortId в `XRAY_SHORT_IDS` в `variables.env`.

После создания пользователя примените изменения:

```text
/restart
```

Получить ссылку:

```text
/link alice
```

Бот вернет VLESS-ссылку с подставленным:

```text
sid=<shortId>
```

Эту ссылку нужно импортировать в клиент, который поддерживает VLESS + Reality.

## Удаление пользователя

В Telegram:

```text
/delete_user alice
```

Бот:

1. Находит shortId пользователя в Redis.
2. Удаляет shortId из `XRAY_SHORT_IDS`.
3. Удаляет пользователя из Redis.

Если это был последний пользователь, `XRAY_SHORT_IDS` вернется к:

```env
XRAY_SHORT_IDS='[""]'
```

После удаления примените изменения:

```text
/restart
```

## Команды бота

- `/help` - показать подсказку со всеми командами.
- `/health` - проверить состояние Xray и Reality/SNI.
- `/restart` - пересобрать config и перезапустить Xray. Используйте после создания/удаления пользователя.
- `/create_user <username>` - создать пользователя, сгенерировать shortId и добавить его в `XRAY_SHORT_IDS`.
- `/delete_user <username>` - удалить пользователя и убрать его shortId из `XRAY_SHORT_IDS`.
- `/users` - показать список пользователей и их shortId.
- `/link <username>` - получить VLESS-ссылку пользователя с `sid`.
- `/links <username>` - алиас для `/link`.
- `/client_routing` - получить клиентские routing-правила.
- `/add_sni <hostname>` - добавить SNI-кандидат для Reality fallback.
- `/sni_list` - показать список SNI-кандидатов.

## Как использовать сервис

Обычный сценарий:

1. Запустить configurator.
2. Проверить `/health`.
3. Запустить Xray через `/start` или `/restart`.
4. Запустить Telegram-бота.
5. Создать пользователя через `/create_user username`.
6. Выполнить `/restart`.
7. Получить ссылку через `/link username`.
8. Импортировать ссылку в клиент.

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

Redis внутри bot-контейнера:

```bash
docker exec -it xray-bot redis-cli HGETALL xray:users
```

## Важные замечания

- `secrets.env` содержит приватный Reality key. Не публикуйте этот файл.
- После изменения пользователей, SNI или templates нужен restart Xray.
- `XRAY_SHORT_IDS='[""]'` разрешает подключение без `sid`; после создания пользователей лучше использовать ссылки с персональным `sid`.
- Configurator API рассчитан на локальный доступ. Не публикуйте порт `8080` наружу.
- Для работы на `443` контейнер configurator должен иметь право слушать этот порт.
