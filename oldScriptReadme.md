# Старые скрипты (не актуально!)


**Вы получите:**
1. основной [VLESS RAW REALITY](https://gozargah.github.io/marzban/ru/docs/xray-inbounds) xtls-rprx-vision на 443 порту с рандомным сайтом маскировки.
2. вспомогательный vless на 8443 порту.
3. вспомогательный Shadowsocks на 2040 порту.

## Стандартная установка
Зайдите в консоль на сервер, например, с помощью PuTTY и введите команду:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAY.sh)"
```
Подождите около 5 минут, пока устанавливаются обновления и ядро. В конце установки зелёными цветом будут подсвечены 3 готовых конфига. Вам останется только вставить их в ваше клиентское приложение.

## Установка для хостеров
Если вы хотите автоматически развертывать личный VPN для своих клиентов и у вас есть авторизация в Телеграме. 
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAY.sh)" -- chatID tgTOKEN
```
chatID — id вашего клиента в ТГ, tgTOKEN — токен вашего бота. Просьба указывать автора и ссылку на эту страницу в качестве первоисточника.


После настройки ядра скрипт автоматически пришлет готовые конфиги с инструкцией в ТГ бот.


### Если у вас занят 443 порт

Сделал выбор до 3 портов, два будут vless и третий ss:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAYno443.sh)" -- 456 321 2000

```


**Разработан скрипт автоматизации для получения selfsteal** - вставьте ваш домен!
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/main/autoXRAYselfsteal.sh)" -- вашДОМЕН.com
```
**Вы получите:**
1. основной [VLESS RAW REALITY](https://gozargah.github.io/marzban/ru/docs/xray-inbounds) xtls-rprx-vision на 443 порту с рандомным сайтом маскировки.
2. вспомогательный vless на 8443 порту.
3. вспомогательный Shadowsocks на 2040 порту.
