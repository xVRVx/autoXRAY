# Ставим Cloudflare WARP-cli
```
echo -e "1\n1\n40000" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) w
```

Удаляем WARP-cli
```
echo -e "y" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) u

```


Находим
```bash
  {
	"outboundTag": "block",
	"domain": [
	  "ifconfig.me",
	  "checkip.amazonaws.com",
	  "pify.org",
	  "2ip.io",
	  "geosite:category-ip-geo-detect"
	]
  }
```

Меняем на
```bash
	{
	  "outboundTag": "warp",
	  "domain": ["ifconfig.me","checkip.amazonaws.com","pify.org",
"2ip.io","geosite:category-ip-geo-detect","habr.com",,"geosite:canva","geosite:whatsapp"]
	}
```

**Чтобы включить**: меняем "outboundTag": "block" на "outboundTag": "warp"
**Чтобы редактировать**: меняем строку "domain"

После изменений ядро надо перезапустить: **systemctl restart xray**

## Если WARP по скрипту не ставится

Вы вытащили сектор «приз», и скрипту, скорее всего, не хватает виртуализации или инструкций процессора.

**Удалите скрипт**
```
echo -e "y" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) u
```


**Установите WARP-cf**
```
bash -c "$(curl -L https://raw.githubusercontent.com/xVRVx/autoXRAY/refs/heads/main/test/warp/warp-cf.sh)"
```


**Как удалить**
```
warp-cli disconnect; apt-get remove cloudflare-warp -y
```
