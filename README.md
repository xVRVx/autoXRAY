# autoXRAY - личный ВПН сервер
Bash-скрипт для автоматической настройки ядра [Xray](https://github.com/XTLS/Xray-core). Предназначен для удобного получения актуальных конфигураций VPN для семейного/личного использования, настраивает selfsteal [VLESS RAW REALITY](https://github.com/XTLS/REALITY/blob/main/README.en.md).

**UPD: Описание неактуальных скриптов перемещено в [oldScriptReadme.md](https://github.com/xVRVx/autoXRAY/blob/main/oldScriptReadme.md).**

**UPD: Добавлен новый раздел — [построение моста RU -> EU](#%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%B0%D0%B8%D0%B2%D0%B0%D0%B5%D0%BC-%D0%BC%D0%BE%D1%81%D1%82-ru---eu).**

Рекомендуемая система: чистая Ubuntu 24/Debian 12 с root правами.


### Конфигурация с клиентским конфигом для РФ (рекомендуется)
Будем использовать маскировку под собственный сайт (selfsteal), который крутится на вашем же VPS. 

Для установки надо [арендовать VPS](#выбор-сервера-подбирал-промо-тарифы) и [получить домен](#получаем-домен).

Автоматически перенаправляет весь ру трафик напрямую - лучшее решение.
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAYselfstealConfRU.sh)" -- вашДОМЕН.com
```
Минусы: меньше приложений поддерживают данную функцию.



## Выбор сервера (подбирал промо тарифы)

- [senko.digital](https://senko.digital/?ref=47670) - от 1.5€, есть днс-хостинг и домены для selfsteel.
- [notbad](https://my.notbad.cloud/?from=188) - от 3$, есть оплата рублями, хороший курс и канал.
- [WAICORE](https://waicore.com/?from=3063) - от 2€ промо, есть оплата рублями.
- [XorekCloud](https://xorek.cloud/?from=28522) - тут есть новый промо тариф, за 150 руб./мес.
- [hosting-russia](https://hosting-russia.ru/?p=57731) - ру сервера от 180 рублей, для моста ru-eu.
- [rocketcloud](https://rocketcloud.ru/?affiliate_uuid=e9ad7432-7898-4de2-8606-38eb90e0c1a6) - ру сервера от 100 рублей, для моста ru-eu.



## Получаем домен

**Получаем бесплатный поддомен**: регестрируемся в [cloudns](https://www.cloudns.net/aff/id/1919804/). Далее: Управление -> DNS Хостинг -> Создать зону -> Свободная зона -> вводим рандомное имя для поддомена.
Теперь надо создать A-запись: Новая запись -> Тип А -> Хост (имя субдомена) -> Указывает на (IP адрес вашего VPS).

**Платный домен и бесплатный днс-хостинг можно получить** в [senko.digital](https://senko.digital/?ref=47670) за крипту. Здесь же можно арендовать промо VPS за крипту.
Платные сервисы, как правило, работают стабильнее.

Помните, что DNS-записи обновляются не сразу: иногда это занимает 15 минут, иногда — час и более. Проверить - [xseo.in/dns](https://xseo.in/dns).



## Настройка VPN
**Скопируйте конфиг в специализированное приложение:**

- iOS: [Happ](https://www.happ.su/main/ru) или [v2rayTun](https://v2raytun.com/) или FoXray
- Android: [Happ](https://www.happ.su/main/ru) или [v2rayTun](https://v2raytun.com/) или v2rayNG
- Windows: [winLoadXray](https://github.com/xVRVx/winLoadXRAY/releases/latest/download/winLoadXRAY.exe), [v2rayN](https://github.com/2dust/v2rayN/releases/), [Throne](https://github.com/throneproj/Throne/releases), (Happ?)


## Пояснение и рекомендации

Сейчас в сети много инструкций по установке GUI-панелей, таких как PasarGuard, 3x-ui или новая RemnaWave. Однако все они избыточны для домашнего использования, так как предназначены для крупных проектов и отличаются высокой сложностью настройки (также используют ядро xray). 

Мануал, который необходимо пройти до получения первого рабочего конфига, занимает более 10 страниц. 
Кроме того, подходящий конфиг для Xray нужно ещё поискать и правильно настроить — с этим отлично справляется данный скрипт.

Без GUI и базы данных Xray потребляет меньше ресурсов сервера и отлично подходит для запуска на слабых VPS-конфигурациях!

При каждом запуске autoXRAY генерирует новые UUID, ключи и пароли для защиты пользователей.

**Преимущества selfsteal**
- Сайт всегда работает на вашем ВПС - устраняется точка отказа.
- Ниже пинг - быстрее соединение.
- Не используются CDN, которые есть на многих популярных сайтах.
- Лучше маскировка - т.к. сайт находится в той же сети что и сервер.

**Обновить ядро xray**
```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```


## Смена паролей и сайта маскировки

Запустите скрипт заново - он сформирует новые конфигурации VPN для YouTube, chatGPT и других нужных сайтов.

## Повышенная маскировка

Настоятельно рекомендуется: сменить порт ssh со стандартного 22 на другой и/или сделать вход на сервер по ключу. Настроить файрвол и оставить открытыми порты для работы скрипта: ваш ssh порт, 80 для certbot, 443 для xray.

Если вы хотите погрузиться в дело конфигурации xray есть отличный [справочник](https://xtls.github.io/ru/config/outbounds/vless.html) и [руководство](https://github.com/XTLS/Xray-core/discussions/3518).

Редактировать конфиг можно тут: **/usr/local/etc/xray/config.json**

После изменений ядро надо перезапустить: **systemctl restart xray**



### Конфигурация с клиентским конфигом VPN для Китая
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAYselfstealConfChina.sh)" -- вашДОМЕН.com
```
Разработан по китайским [мануалам](https://xtls.github.io/ru/document/level-0/ch08-xray-clients.html#_8-3-%D0%B4%D0%BE%D0%BF%D0%BE%D0%BB%D0%BD%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D0%B5-%D0%B7%D0%B0%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-1-%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B8%D0%BA%D0%B0-xray-core-%D0%BD%D0%B0-%D0%BF%D0%BA-%D0%B2%D1%80%D1%83%D1%87%D0%BD%D1%83%D1%8E).


## Настраиваем мост RU -> EU
Многие столкнулись с блокировками хостинг-сетей по TLS (особенно при использовании мобильного интернета). Существует решение — построение моста между серверами в разных локациях. Для этого необходимо:

1) На заблокированный чистый VPS ставим стандартный рекомендованный скрипт и копируем конфиг для роутера:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAYselfstealConfRU.sh)" -- поддомен1.вашДОМЕН.com
```
2) На ru VPS ставим новый скрипт (здесь нам понадобится vless конфиг для роутера):
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAYselfstealConfRUbrEU.sh)" -- поддомен2.вашДОМЕН.com "vless://вашКонфиг"
```
Установится прокси мост между серверами, итоговая цепочка: конфиг клиента -> ru VPS -> eu VPS -> зарубежный сайт

**Если вы хотите пускать ютуб через ру впс (у вас он без ТСПУ или вы поставили и настроили [zapret4rocket](https://github.com/IndeecFOX/zapret4rocket))**

Тогда в конфиге ру впс, который лежит /usr/local/etc/xray/config.json надо добавить в строке 38:
```bash
"geosite:youtube",
"youtube.com",
"googlevideo.com",
"ytimg.com",
"ggpht.com",
```
и перезапустить ядро: **systemctl restart xray**

Скрипты будут дорабатываться до актуального состояния.

**[Поддержать автора.](https://pay.cryptocloud.plus/pos/Weu1Y0fOhLho0nte)**
