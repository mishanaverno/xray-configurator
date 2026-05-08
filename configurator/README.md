# Xray Configurator

Configurator-контейнер собирает и запускает Xray-конфигурацию из preset-шаблонов, управляет SNI-кандидатами, geodata-файлами, client routing и shortId для пользователей.

Контейнер поднимает:

- Xray на локальном `127.0.0.1:8443`.
- Nginx stream proxy на `:443`.
- Локальный HTTP API на `127.0.0.1:8080`.

Для `reality` и `reality_xhttp_relay` nginx включает proxy protocol, потому что Reality inbound принимает его через `sockopt.acceptProxyProtocol`.
Для `xhttp_relay` nginx прокидывает внешний порт из env `XHTTP_PUBLIC_PORT` в `127.0.0.1:1050` без proxy protocol, потому что xHTTP inbound принимает обычный TLS-поток.

Preset `reality_xhttp_relay` также может управлять relay через SSH. Для этого используются локальные endpoints:

```text
/relay/health
/relay/start
/relay/stop
/relay/restart
```

Они выполняют на relay-сервере локальные configurator API-команды через SSH.

HTTP API закрыт nginx-правилами `allow 127.0.0.1; deny all;`, поэтому предполагается локальный доступ из bot/host окружения.

## Директории

Основной volume:

```text
/usr/share/xray
```

Внутри него:

```text
/usr/share/xray/config.json
/usr/share/xray/link.txt
/usr/share/xray/secrets.env
/usr/share/xray/geosite.dat
/usr/share/xray/geoip.dat
/usr/share/xray/templates/
```

Preset-шаблоны копируются из:

```text
/tmp/xray/presets/<preset>
```

в:

```text
/usr/share/xray/templates
```

По умолчанию используется preset `reality`. Доступные preset'ы:

```text
reality
reality_xhttp_relay
xhttp_relay
```

Копирование происходит только если файла в volume еще нет. Если preset меняется, текущая директория `templates/` переносится в backup `templates.backup.YYYYMMDDHHMMSS`, после чего копируется выбранный preset.

## Шаблоны

Основные template-файлы для клиентского Reality preset'а:

```text
templates/variables.env
templates/inbound.json
templates/outbound.json
templates/routing.json
templates/client_routing.json
templates/link.txt
templates/sni_list
```

Для серверных preset'ов часть файлов может отсутствовать. Например, `xhttp_relay` не содержит `client_routing.json`, `link.txt` и `sni_list`, потому что не выдает клиентские ссылки и не использует Reality/SNI.

Nginx-конфиги лежат отдельно:

```text
nginx/reality.conf
nginx/xhttp_relay.conf
```

`entrypoint.sh` выбирает `nginx/reality.conf` для всех preset'ов `reality*` и `nginx/xhttp_relay.conf` для preset `xhttp_relay`.

### `variables.env`

Пример:

```env
XRAY_LOG_LEVEL=warning
XRAY_REALITY=google.com
XRAY_SHORT_IDS='[""]'
LINK1_TAG=VLESS_CONF
```

`XRAY_SHORT_IDS` должен быть валидным JSON-массивом строк. Он подставляется в `inbound.json` как JSON, а не как строка:

```json
"shortIds": ${XRAY_SHORT_IDS}
```

Пока пользователей нет, допустим дефолт:

```env
XRAY_SHORT_IDS='[""]'
```

Когда появляется хотя бы один пользователь, пустой shortId убирается:

```env
XRAY_SHORT_IDS='["a1b2c3d4"]'
```

Если удален последний пользователь, значение возвращается к:

```env
XRAY_SHORT_IDS='[""]'
```

### `secrets.env`

Создается автоматически при первом старте:

```env
XRAY_UUID=...
XRAY_PRIVATE_KEY=...
XRAY_PUBLIC_KEY=...
XRAY_HOST_IP=...
```

Private key не печатается в логи. Файл нужно считать секретным.

## Жизненный цикл старта

При запуске `entrypoint.sh`:

1. Проверяет и создает volume-директории.
2. Генерирует `secrets.env`, если его еще нет.
3. Копирует templates выбранного preset'а в volume.
4. Пытается обновить `geosite.dat` и `geoip.dat`.
5. Запускает `fcgiwrap`.
6. Запускает nginx.
7. В фоне пытается обновить `geosite.dat` и `geoip.dat`.

Geodata обновляется best-effort и не блокирует доступность локального API. Если скачивание не удалось, контейнер продолжит работу с существующими файлами.

## Генерация Xray config

`generate_config.sh`:

1. Загружает `secrets.env`.
2. Загружает `templates/variables.env`.
3. Подставляет переменные через `envsubst`.
4. Валидирует JSON через `jq`.
5. Собирает `/usr/share/xray/config.json`.
6. Генерирует `/usr/share/xray/link.txt`, если preset содержит `templates/link.txt`.

Рабочие `config.json` и `link.txt` заменяются только после успешной генерации во временные файлы. Для preset'ов без `link.txt` старый `/usr/share/xray/link.txt` удаляется.

## HTTP API

Все endpoint-ы доступны через GET.

### `/start`

Для preset `reality` проверяет `XRAY_REALITY`, затем генерирует config и запускает Xray. Для остальных preset'ов Reality/SNI проверка пропускается.

### `/stop`

Останавливает Xray по pid-файлу.

### `/health`

Проверяет:

- pid-файл;
- живой процесс;
- доступность `127.0.0.1:8443`;
- TLS 1.3 health текущего `XRAY_REALITY`.

### `/links`

Возвращает содержимое `link.txt`, если текущий preset генерирует клиентскую ссылку.

Бот использует этот endpoint как базу и добавляет пользовательский `sid`.

### `/client-routing`

Возвращает содержимое `templates/client_routing.json`.

Перед ответом проверяет, что файл существует и является валидным JSON.

### `/sni/add?sni=<hostname>`

Добавляет hostname в `templates/sni_list`.

Пример:

```bash
curl 'http://127.0.0.1:8080/sni/add?sni=www.microsoft.com'
```

### `/sni/list`

Возвращает текущий список SNI-кандидатов.

### `/short-ids/add?short_id=<hex>`

Добавляет Reality shortId в `XRAY_SHORT_IDS`.

Требования:

- hex-строка;
- четная длина;
- от 2 до 16 символов.

Пример:

```bash
curl 'http://127.0.0.1:8080/short-ids/add?short_id=a1b2c3d4'
```

Если в массиве был пустой `""`, он удаляется при добавлении первого реального shortId.

### `/short-ids/remove?short_id=<hex>`

Удаляет Reality shortId из `XRAY_SHORT_IDS`.

Пример:

```bash
curl 'http://127.0.0.1:8080/short-ids/remove?short_id=a1b2c3d4'
```

Если после удаления не осталось id, записывает:

```env
XRAY_SHORT_IDS='[""]'
```

### `/update`

Скачивает свежие:

```text
geosite.dat
geoip.dat
```

Загрузка идет во временные файлы. Старые geodata-файлы заменяются только после успешного скачивания.

## SNI auto-healing

Перед стартом Xray вызывается `ensure_reality.sh`.

Если текущий `XRAY_REALITY` валиден и отвечает TLS 1.3, он остается.

Если проверка падает, скрипт перебирает `sni_list` и заменяет `XRAY_REALITY` на первый рабочий hostname.

## Запуск

Сборка:

```bash
docker build -t xray-conf:latest ./configurator
```

Пример запуска:

```bash
docker run --rm \
  --network host \
  -v /path/to/xray-volume:/usr/share/xray \
  xray-conf:latest
```

Для stream proxy нужен доступ к порту `443`.

## Эксплуатационные замечания

- После изменения `variables.env`, shortId, SNI или templates нужно выполнить `/start` или `/restart` через бота, чтобы config был пересобран.
- `secrets.env` содержит приватный Reality key, его нельзя публиковать.
- `XRAY_SHORT_IDS='[""]'` разрешает подключение без `sid`. Для персональных пользователей лучше иметь непустые shortId.
- `client_routing.json` предназначен для клиентских правил маршрутизации и не участвует в серверном `config.json`.
