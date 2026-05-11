# Xray Telegram Bot

Telegram-бот для управления локальным Xray configurator API. Бот не меняет Xray напрямую: он ходит в HTTP API configurator-контейнера и отправляет ответы в разрешенный Telegram-чат.

## Возможности

- Проверка состояния Xray.
- Перезапуск Xray через configurator.
- Выдача VLESS-ссылок из configurator.
- Управление SNI-кандидатами.
- Получение client routing JSON для настройки клиента.
- Управление slave через configurator SSH-control endpoints.
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
XRAY_API_TIMEOUT_MS=20000
```

`CHAT_ID` ограничивает доступ к боту одним чатом. Сообщения из других чатов игнорируются.

## Команды

Ответы команд автоматически удаляются. Дефолтное время жизни сообщения - 1 час.
На неизвестные slash-команды бот отвечает подсказкой с предложением вызвать `/help`.

### `/help`

Показывает список актуальных команд с краткими пояснениями.

### `/health`

Проверяет состояние Xray через `/health`.

### `/restart`

Останавливает и запускает Xray через `/stop` и `/start`.

### `/links`

Получает содержимое `/links` из configurator. Каждая непустая строка отправляется отдельным Telegram-сообщением.

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

### `/slave_health`

Проверяет slave через SSH с master configurator-сервера.

### `/slave_start`

Запускает Xray на slave.

### `/slave_stop`

Останавливает Xray на slave.

### `/slave_restart`

Перезапускает Xray на slave.

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
  xray-bot:latest
```

Если bot-контейнер не использует host network, `XRAY_API_BASE` должен указывать на доступный из контейнера адрес configurator API.

## Важные замечания

- После ручных изменений preset/templates активный Xray применит их только после `/restart`.
- Если configurator API недоступен, команды управления вернут ошибку.
