# Старые скрипты (не актуально!)

## Экспериментальный скрипт с GRPC XHTTP RAW WS XTLS/TLS

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAYselfTLS2.sh)" -- вашДОМЕН.com
```

## reality raw/xhttp, ss2022
```bash

bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAYselfConfRUxhttp.sh)" -- вашДОМЕН.com
```


**Вы получите:**
1. основной [VLESS RAW REALITY](https://gozargah.github.io/marzban/ru/docs/xray-inbounds) xtls-rprx-vision на 443 порту с рандомным сайтом маскировки.
2. вспомогательный vless на 8443 порту.
3. вспомогательный Shadowsocks на 2040 порту.

## Стандартная установка
Зайдите в консоль на сервер, например, с помощью PuTTY и введите команду:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAY.sh)"
```
Подождите около 5 минут, пока устанавливаются обновления и ядро. В конце установки зелёными цветом будут подсвечены 3 готовых конфига. Вам останется только вставить их в ваше клиентское приложение.

## Установка для хостеров
Если вы хотите автоматически развертывать личный VPN для своих клиентов и у вас есть авторизация в Телеграме. 
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAY.sh)" -- chatID tgTOKEN
```
chatID — id вашего клиента в ТГ, tgTOKEN — токен вашего бота. Просьба указывать автора и ссылку на эту страницу в качестве первоисточника.


После настройки ядра скрипт автоматически пришлет готовые конфиги с инструкцией в ТГ бот.


### Если у вас занят 443 порт

Сделал выбор до 3 портов, два будут vless и третий ss:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAYno443.sh)" -- 456 321 2000

```


**Разработан скрипт автоматизации для получения selfsteal** - вставьте ваш домен!
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAYselfsteal.sh)" -- вашДОМЕН.com
```
**Вы получите:**
1. основной [VLESS RAW REALITY](https://gozargah.github.io/marzban/ru/docs/xray-inbounds) xtls-rprx-vision на 443 порту с рандомным сайтом маскировки.
2. вспомогательный vless на 8443 порту.
3. вспомогательный Shadowsocks на 2040 порту.


## Повышенная маскировка

В идеале, надо настроить ваше клиентское приложение, чтобы оно отправляло российский трафик напрямую, минуя vpn сервер. Также можно: перенаправлять ру трафик в [Cloudflare WARP](https://marzban-docs.sm1ky.com/tutorials/cloudflare-warp/), создать второй ру сервер и перенаправлять его туда.

Если вы хотите погрузиться в дело конфигурации xray есть отличный [справочник](https://xtls.github.io/ru/config/outbounds/vless.html) и [руководство](https://github.com/XTLS/Xray-core/discussions/3518).

Редактировать конфиг можно тут: /usr/local/etc/xray/config.json

После изменений ядро надо перезапустить: systemctl restart xray

Также рекомендуется: сменить порт ssh со стандартного 22 на другой или сделать вход на сервер по ключу. Настроить файрвол и оставить открытыми порты для работы скрипта:80,  443, 8443, 2040.




## selfsteal

Есть такое понятие как селфстил (selfsteal), когда на самом сервере стоит сайт для маскировки, это дает много плюсов, но требует повышенных знаний и своего домена, настройки реверс-прокси, таких как nginx и маскировочного сайта.

**Требования:**
1. Свой домен, не в СНГ зонах.
2. ДНС-хостинг.
3. Debian 12 / Ubuntu 24 (на других не тестировалось).

Необходимо настроить A-запись вашего домена на IP-адрес вашего сервера, чтобы можно было выпустить SSL-сертификат.

**Преимущества:**
- Сайт всегда работает и устраняется точка отказа.
- Ниже пинг - быстрее соединение.
- Не используются CDN, которые есть на многих популярных сайтах.
- Лучше маскировка - т.к. сайт находится в той же сети что и сервер.


### Конфигурация с клиентским конфигом VPN для Китая
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/old/autoXRAYselfstealConfChina.sh)" -- вашДОМЕН.com
```
Разработан по китайским [мануалам](https://xtls.github.io/ru/document/level-0/ch08-xray-clients.html#_8-3-%D0%B4%D0%BE%D0%BF%D0%BE%D0%BB%D0%BD%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D0%B5-%D0%B7%D0%B0%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-1-%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B8%D0%BA%D0%B0-xray-core-%D0%BD%D0%B0-%D0%BF%D0%BA-%D0%B2%D1%80%D1%83%D1%87%D0%BD%D1%83%D1%8E).


