# Xray Telegram Bot

Telegram-бот для управления локальным Xray configurator API. Бот не меняет Xray напрямую: он ходит в HTTP API configurator-контейнера, хранит пользователей во встроенном Redis и выдает клиентские ссылки с персональным Reality `sid`.

## Возможности

- Проверка состояния Xray.
- Перезапуск Xray через configurator.
- Выдача VLESS-ссылки для конкретного пользователя.
- Создание и удаление пользователей с персональными shortId.
- Управление SNI-кандидатами.
- Получение client routing JSON для настройки клиента.
- Автоуведомления в Telegram, если health check упал или восстановился.

## Переменные окружения

Обязательные:

```env
BOT_TOKEN=123456:telegram-bot-token
CHAT_ID=123456789
```

Опциональные:

```env
XRAY_API_BASE=http://127.0.0.1:8080
REDIS_USERS_KEY=xray:users
```

`CHAT_ID` ограничивает доступ к боту одним чатом. Сообщения из других чатов игнорируются.

## Redis

Redis запускается внутри bot-контейнера. Бот хранит пользователей в Redis hash:

```text
xray:users
```

Формат:

```text
username -> shortId
```

Например:

```text
alice -> a1b2c3d4
```

Redis нужен для команд `/create_user`, `/delete_user`, `/link` и `/links`.

Чтобы пользователи не терялись при пересоздании контейнера, подключайте volume в `/data`.

## Команды

### `/health`

Проверяет состояние Xray через `/health`.

### `/restart`

Останавливает и запускает Xray через `/stop` и `/start`.

Нужен после изменения пользователей, потому что shortId записываются в `variables.env`, а Xray перечитывает их при генерации и старте конфига.

### `/create_user <username>`

Создает пользователя.

Пример:

```text
/create_user alice
```

Что происходит:

1. Генерируется shortId длиной 8 hex-символов.
2. Пара `username -> shortId` сохраняется в Redis.
3. shortId добавляется в configurator `variables.env` в `XRAY_SHORT_IDS`.

Допустимый username: латинские буквы, цифры, `_`, `-`, до 64 символов.

После создания пользователя нужно выполнить:

```text
/restart
```

### `/delete_user <username>`

Удаляет пользователя.

Пример:

```text
/delete_user alice
```

Что происходит:

1. Бот берет shortId пользователя из Redis.
2. Удаляет shortId из `XRAY_SHORT_IDS`.
3. Удаляет пользователя из Redis.

Если после удаления не осталось shortId, configurator возвращает дефолт:

```env
XRAY_SHORT_IDS='[""]'
```

После удаления пользователя нужно выполнить:

```text
/restart
```

### `/link <username>`

Возвращает VLESS-ссылку для пользователя с подставленным `sid`.

Пример:

```text
/link alice
```

Также поддерживается алиас:

```text
/links alice
```

### `/client_routing`

Возвращает содержимое `client_routing.json`.

Если файл большой, бот разобьет ответ на несколько сообщений.

### `/add_sni <hostname>`

Добавляет SNI-кандидат.

Пример:

```text
/add_sni www.microsoft.com
```

### `/sni_list`

Возвращает текущий список SNI-кандидатов.

## Запуск

Сборка образа:

```bash
docker build -t xray-bot:latest ./bot
```

Пример запуска:

```bash
docker run --rm \
  --network host \
  -e BOT_TOKEN="$BOT_TOKEN" \
  -e CHAT_ID="$CHAT_ID" \
  -e XRAY_API_BASE="http://127.0.0.1:8080" \
  -v /usr/local/share/xray/bot-data:/data \
  xray-bot:latest
```

Если bot-контейнер не использует host network, `XRAY_API_BASE` должен указывать на доступный из контейнера адрес configurator API.

## Важные замечания

- `/create_user` и `/delete_user` меняют `variables.env`, но активный Xray применит изменения только после `/restart`.
- `sid` в ссылке должен совпадать с одним из значений `XRAY_SHORT_IDS`.
- Если пользователь есть в Redis, но его shortId отсутствует в `variables.env`, ссылка будет выдана, но подключение не пройдет Reality handshake.
- Если configurator API недоступен, создание и удаление пользователей не будут завершены.
