## 🛡️ autoXRAY - личный VPN-сервер
Bash-скрипт для автоматической настройки ядра [Xray](https://github.com/XTLS/Xray-core). Позволяет быстро получить актуальные конфигурации VPN для личного или семейного использования.
### ✨ Что вы получите 

* **4 протокола на порту 443:** `VLESS XHTTP TLS`, `VLESS RAW TLS VISION`, `Hysteria2` и `Web Proxy TG`(по желанию)
* **Умная подписка:** авто-роутинг (RU напрямую, реклама и трекеры заблокированы)
* **Веб-страница сервера:** готовые ссылки для клиентов и QR-коды для смартфона
* **Страница маскировки:** с защитой от active probing

## 📌 Что нового

| Обновление | Суть |
|:--|:--|
| **UPD5** | Ядро переведено на `v26.10.31` — обновите клиентские приложения |
| **UPD4** | Все инбаунды переведены на **443** порт |
| **UPD3** | Добавлен **Web Proxy TG** |
| **UPD2** | Описание неактуальных скриптов → [old/oldScriptReadme.md](old/oldScriptReadme.md) |
| **UPD1** | Добавлен раздел [«Мост RU → EU»](#bridge) |

---

<a id="install"></a>
## 🚀 Быстрый старт

Для установки надо [арендовать VPS](#servers), [получить домен](#domain) и запустить скрипт:

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAY2.sh)" -- вашДОМЕН.com
```

Скрипт сам поставит Xray и Nginx, выпустит TLS-сертификат, сгенерирует UUID/ключи/пароли, поднимет сайт-маскировку и выдаст готовые ссылки на конфиги.

---

## 📋 Требования

| Параметр | Значение |
|:--|:--|
| **ОС** | Чистый **Debian 12 / 13** (Ubuntu работает, но скрипт предупредит) |
| **Сервер** | VPS с собственным IP, чистая система с root доступом |
| **Домен** | Свой домен **или бесплатный поддомен**, A-запись → IP сервера |
| **Порты** | `80` (ACME) и `443` (всё остальное) должны быть свободны |
| **Время** | ~5 минут на установку |


---
<a id="servers"></a>
## 🖥️ Выбор сервера

Подбирал строго **без KYC** (*Know Your Customer* — обязательная верификация личности: паспорт, телефон, карта).

### 🇪🇺 EU — самые стабильные (DE / NL)

| Провайдер | Локации | Цена | Комментарий |
|:--|:--|:--|:--|
| [XorekCloud](https://xorek.cloud/?from=28522) | DE / NL | от 149 ₽ | Оплата рублями |
| [netgrid](https://netgrid.host/ru?from=5893) | DE / NL / CZ / PL / USA и др. | от 3 € | Большой выбор локаций |
| [hostoff](https://hostoff.net/vps?ref=CODE197DF457) | DE / NL / PL | от 5 € | Хороший канал |
| [notbad](https://my.notbad.cloud/?from=188) | DE / NL | от 4 $ | Оплата рублями, хороший курс и канал |
| [senko.digital](https://senko.digital/?ref=47670) | DE / NL / FI | от 2 € | DNS-хостинг + домены, оплата СБП |
| [serv.host](https://serv.host/?from=44424) | RU / DE / NL / FI и др. | от 360 ₽/мес | — |

> [!TIP]
> Если брать **NL-локацию**, есть шанс «урвать» VPS без рекламы на YouTube.

### 🇷🇺 RU — для моста

| Провайдер | Цена |
|:--|:--|
| [CloudCore](https://cloudcore.ru/?affiliate_uuid=e9ad7432-7898-4de2-8606-38eb90e0c1a6) | от 100 ₽/мес |
| [time-host](https://time-host.net/?from=47217) | от 140 ₽/мес |

> [!NOTE]
> Промо-тарифы постоянно заканчиваются и, как правило, сильно урезаны по ресурсам.

> [!WARNING]
> Подсети и ip популярных хостинг-провайдеров заблокированы РКН. К ним порой даже невозможно подключиться по SSH без VPN. С недавних пор это лотерея, так что имейте это ввиду.
---
<a id="domain"></a>
## 🌐 Получаем домен

### 🆓 Бесплатный поддомен

1. Зарегистрируйтесь в [cloudns](https://www.cloudns.net/aff/id/1919804/)
2. **Управление → DNS Хостинг → Создать зону → Свободная зона** → введите случайное имя поддомена
3. Создайте A-запись: **Новая запись → Тип А → Хост (имя субдомена) → Указывает на (IP адрес вашего VPS)**

Альтернативы: [duckdns.org](https://www.duckdns.org/) · [freedns.afraid.org](https://freedns.afraid.org/)

### 💳 Платный домен + бесплатный DNS-хостинг

[senko.digital](https://senko.digital/?ref=47670) — здесь же можно арендовать промо-VPS. Платные домены, как правило, работают стабильнее бесплатных поддоменов.

> [!IMPORTANT]
> DNS-записи обновляются **не сразу**: иногда 15 минут, иногда — час и более. Проверить: [xseo.in/dns](https://xseo.in/dns).

---


## 📱 Подключение клиентов

Скопируйте **ссылку на подписку** со странички подписки в приложение:

| ОС | Поддерживают подписку | Только `vless://` / конфиг для роутера |
|:--|:--|:--|
| **iOS / macOS** | [Happ](https://www.happ.su/main/ru) · [v2rayTun](https://v2raytun.com/) | FoXray, Hiddify |
| **Android** | [Happ](https://www.happ.su/main/ru) · [v2rayTun](https://v2raytun.com/) | v2rayNG, SimpleXray |
| **Windows** | [Happ](https://www.happ.su/main/ru) · [winLoadXray](https://github.com/xVRXx/winLoadXRAY/releases/latest/download/winLoadXRAY.exe) · [v2rayN](https://github.com/2dust/v2rayN/releases/) | v2rayTun, Throne, Hiddify |
| **Linux** | [Happ](https://www.happ.su/main/ru) · [v2rayN](https://github.com/2dust/v2rayN/releases/) | Throne, Hiddify |

> [!NOTE]
> В Happ маршрутизация **встроенная** — выключите её, если включали сторонние сервисы. Подписка добавляется кнопкой «⚡ Add to HAPP».

---

## 🔄 Обновление

### 🔹 Только ядро Xray

```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

### 🔹 Весь скрипт

| Что используете | Что делать |
|:--|:--|
| **Подписку** | Запомните её ссылку → переустановите скрипт → в новой папке `/var/www/домен/xxxXXXxxx.json` поменяйте путь на старый → после этого обновите подписку в приложении |
| **Только ключи** | Такой возможности нет. P.S.: удобно воспользоваться QR-кодом для переноса на мобильное устройство |

---

## 🧹 Удаление

**🔹 Удаляем nginx & acme**

```bash
systemctl disable nginx; systemctl stop nginx; apt remove nginx -y; ~/.acme.sh/acme.sh --uninstall 2>/dev/null; rm -rf /root/.acme.sh /var/lib/xray
```

**🔹 Удаляем Xray**

```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```

**🔹 Удаляем web-proxy**

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/refs/heads/main/test/telegram/web-proxy-uninstal.sh)"
```

---
<a id="bridge"></a>
## 🌉 Мост RU → EU

Многие сталкиваются с блокировками хостинг-сетей по TLS (особенно на мобильном интернете). Решение — мост между серверами в разных локациях.

**1)** На заблокированный чистый VPS ставим стандартный рекомендованный скрипт и берём получившийся **VLESS XHTTP TLS EXTRA**:

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAY2.sh)" -- поддомен1.вашДОМЕН.com
```

**2)** На RU-VPS ставим скрипт моста (нужен именно `vless XHTTP TLS`):

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/bridgeTLSxhttp.sh)" -- поддомен2.вашДОМЕН.com "vless://вашКонфигXHTTP"
```

Итоговая цепочка:

```
клиент → RU VPS → EU VPS → зарубежный сайт
```

Можно использовать несколько XHTTP-конфигов — все они будут добавлены в мост:

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/bridgeTLSxhttp.sh)" -- поддомен2.Домен.Ком "vless://xhttp1" "vless://xhttp2" "vless://xhttp3"
```

---

## 🔐 Повышенная маскировка

**Настоятельно рекомендуется:**

- сменить порт SSH со стандартного `22` на другой и/или сделать вход по ключу;
- настроить файрвол и оставить открытыми: ваш SSH-порт, `80` (ACME), `443` (всё остальное).

### Ручная настройка Xray

Если хотите углубиться в конфигурацию Xray — есть отличный [справочник](https://xtls.github.io/ru/config/outbounds/vless.html) и [руководство](https://github.com/XTLS/Xray-core/discussions/3518).

Редактировать конфиг: **`/usr/local/etc/xray/config.json`**

После изменений ядро надо перезапустить: **`systemctl restart xray`**

---

## 📨 Telegram Web Proxy

В связи с начавшейся блокировкой Telegram выпущена сборка с **web proxy** на порту 443 и маскировкой под собственный сайт.

**Принцип работы:**

```
443 XRAY → tproxy-server → MTP TELEMT
```

**Конфигурации:**

| Файл | Назначение |
|:--|:--|
| `/etc/telemt/telemt.toml` | Настройки TeleMT |
| `/etc/tproxy-server/config.json` | Конфиг tproxy-сервера |
| `/etc/tproxy-server/profiles.json` | Профили прокси |

При установке скрипт спросит, нужен ли web proxy — отвечайте `y` (по умолчанию), если он вам нужен.

---

## 🧩 Можно поставить WARP

Инструкция по установке - [warp-readme.md](test/warp/warp-readme.md).

---

## ❓ Прочее

### 👥 Конфиги для нескольких пользователей

Одним конфигом могут пользоваться сразу несколько человек. А чтобы управлять пользователями и следить за их трафиком, нужны уже GUI-панели — **3x-ui**, **RemnaWave** или **PasarGuard**.

### 🔑 Смена паролей и сайта маскировки

Запустите скрипт заново — он сформирует новые конфигурации VPN, новые UUID, ключи и пароли, перегенерирует сайт маскировки.

---

Скрипты будут дорабатываться до актуального состояния.

**[Поддержать автора.](https://pay.trybit.com/pos/Weu1Y0fOhLho0nte)**

