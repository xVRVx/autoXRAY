# Сборка с MTProto proxy FakeTLS для ТГ

В связи с начавшейся блокировкой Telegram выпускаю новую сборку с MTProxy на порту 443 и маскировкой под собственный сайт на основе [Telemt](https://github.com/telemt/telemt/blob/main/docs/QUICK_START_GUIDE.ru.md).

**Основной скрипт для euVPS**
```
bash -c "$(curl -L https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/autoXRAY1-test.sh)" -- поддомен1.Домен.Ком
```


Всех дольше будут работать каскадные варианты подключения.

**Для моста (ru/kz VPS)**
```
bash -c "$(curl -L https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/autoXRAYselfRUbrEUxhttp-test.sh)" -- поддомен2.Домен.Ком "vless://xhttp"
```
Также теперь можно использовать несколько xhttp конфигов, все они будут добавлены в мост.


 -- поддомен2.Домен.Ком "vless://xhttp1" "vless://xhttp2" "vless://xhttp3"

**Как удалить Telemt**
```
systemctl stop telemt; systemctl disable telemt; rm -f /etc/systemd/system/telemt.service /bin/telemt; systemctl daemon-reload
```
