# Если WARP по скрипту не ставится

Вы вытащили сектор «приз», и скрипту, скорее всего, не хватает виртуализации или инструкций процессора.

**Удалите скрипт**
```
echo -e "y" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) u
```


**Установите WARP-cf**
```
bash -c "$(curl -L https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/warp-cf.sh)"
```


**Как удалить**
```
warp-cli disconnect; apt-get remove cloudflare-warp -y
```
