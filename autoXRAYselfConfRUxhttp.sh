#!/bin/bash

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "❌ Ошибка: домен не задан."
    exit 1
fi

echo "Обновление и установка необходимых пакетов..."
apt update && apt install -y jq dnsutils


LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]')

if [ "$LOCAL_IP" != "$DNS_IP" ]; then
    echo "❌ Внимание: IP-адрес ($LOCAL_IP) не совпадает с A-записью $DOMAIN ($DNS_IP)."
    echo "Правильно укажите одну A-запись для вашего домена в ДНС - $LOCAL_IP"
    
    read -p "Продолжить на ваш страх и риск? (y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "Выполнение скрипта прервано."
        exit 1
    fi
    echo "Продолжение выполнения скрипта..."
fi


apt install nginx -y

systemctl enable --now nginx

apt install certbot -y

certbot certonly --webroot -w /var/www/html -d $DOMAIN -m mail@$DOMAIN --agree-tos --non-interactive --deploy-hook "systemctl reload nginx"

CONFIG_PATH="/etc/nginx/sites-available/default"

echo "✅ Записываем конфигурацию в $CONFIG_PATH для домена $DOMAIN"

bash -c "cat > $CONFIG_PATH" <<EOF
server {
    server_name $DOMAIN;
	listen unix:/dev/shm/nginx.sock ssl http2 proxy_protocol;
    set_real_ip_from unix:;
    real_ip_header proxy_protocol;
	
    root /var/www/$DOMAIN;
    index index.php index.html;
	
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers on;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;

    ssl_certificate "/etc/letsencrypt/live/$DOMAIN/fullchain.pem";
    ssl_certificate_key "/etc/letsencrypt/live/$DOMAIN/privkey.pem";

	add_header profile-title "base64:YXV0b1hSQVk=";
	add_header routing "happ://routing/onadd/ewogICAgIk5hbWUiOiAiYXV0b1hSQVkiLAogICAgIkdsb2JhbFByb3h5IjogInRydWUiLAogICAgIlVzZUNodW5rRmlsZXMiOiAidHJ1ZSIsCiAgICAiUmVtb3RlRE5TVHlwZSI6ICJEb0giLAogICAgIlJlbW90ZUROU0RvbWFpbiI6ICIiLAogICAgIlJlbW90ZUROU0lQIjogIiIsCiAgICAiRG9tZXN0aWNETlNUeXBlIjogIkRvSCIsCiAgICAiRG9tZXN0aWNETlNEb21haW4iOiAiIiwKICAgICJEb21lc3RpY0ROU0lQIjogIiIsCiAgICAiR2VvaXB1cmwiOiAiIiwKICAgICJHZW9zaXRldXJsIjogIiIsCiAgICAiTGFzdFVwZGF0ZWQiOiAiIiwKICAgICJEbnNIb3N0cyI6IHt9LAogICAgIk9yZGVyUm91dGluZyI6ICJibG9jay1kaXJlY3QtcHJveHkiLAogICAgIkRpcmVjdFNpdGVzIjogWwogICAgICAgICJjYXRlZ29yeS1ydSIsCiAgICAgICAgImdlb3NpdGU6cHJpdmF0ZSIKICAgIF0sCiAgICAiRGlyZWN0SXAiOiBbCiAgICAgICAgImdlb2lwOnByaXZhdGUiCiAgICBdLAogICAgIlByb3h5U2l0ZXMiOiBbXSwKICAgICJQcm94eUlwIjogW10sCiAgICAiQmxvY2tTaXRlcyI6IFsKICAgICAgICAiZ2Vvc2l0ZTpjYXRlZ29yeS1hZHMiLAogICAgICAgICJnZW9zaXRlOndpbi1zcHkiCiAgICBdLAogICAgIkJsb2NrSXAiOiBbXSwKICAgICJEb21haW5TdHJhdGVneSI6ICJJUElmTm9uTWF0Y2giLAogICAgIkZha2VETlMiOiAiZmFsc2UiCn0=";
    add_header routing-enable 0;

    location ~ /\.ht {
        deny all;
    }
}

server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
		return 301 https://\$host\$request_uri;
    }
}
EOF

echo "✅ Конфигурация nginx обновлена."

systemctl restart nginx


# Создание директории
WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"


# Генерируем сайт маскировку
bash -c "$(curl -L https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/gen_page.sh)" -- $WEB_PATH

# Установка Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

SCRIPT_DIR=/usr/local/etc/xray

# Генерируем переменные
xray_uuid_vrv=$(xray uuid)

key_output=$(xray x25519)
xray_privateKey_vrv=$(echo "$key_output" | awk -F': ' '/PrivateKey/ {print $2}')
xray_publicKey_vrv=$(echo "$key_output" | awk -F': ' '/Password/ {print $2}')

key_mldsa65=$(xray mldsa65)
seed_mldsa65=$(echo "$key_mldsa65" | awk -F': ' '/Seed/ {print $2}')
verify_mldsa65=$(echo "$key_mldsa65" | awk -F': ' '/Verify/ {print $2}')

xray_shortIds_vrv=$(openssl rand -hex 8)

# xray_sspasw_vrv=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)
xray_sspasw_vrv=$(openssl rand -base64 32)

path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

path_xhttp=$(openssl rand -base64 15 | tr -dc 'a-z0-9' | head -c 6)

# ipserv=$(hostname -I | awk '{print $1}')

socksUser=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 6)
socksPasw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)


# Экспортируем переменные для envsubst
export xray_uuid_vrv xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv DOMAIN path_subpage path_xhttp WEB_PATH socksUser socksPasw

# Создаем JSON конфигурацию сервера
cat << 'EOF' | envsubst > "$SCRIPT_DIR/config.json"
{
  "log": {
    "dnsLog": false,
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "none"
  },
  "dns": {
    "servers": [
      "https+local://8.8.4.4/dns-query",
      "https+local://8.8.8.8/dns-query",
      "https+local://1.1.1.1/dns-query",
      "localhost"
    ],
    "queryStrategy": "UseIPv4"
  },
  "inbounds": [
	{
      "tag": "vsRAWrtyXTLS",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "flow": "xtls-rprx-vision",
            "id": "${xray_uuid_vrv}"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
			"path": "/${path_xhttp}44",
            "dest": "4444",
            "xver": 2
          },
          {
            "dest": "3333",
            "xver": 2
          }
        ]
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "xver": 2,
          "target": "/dev/shm/nginx.sock",
          "spiderX": "/",
          "shortIds": [
            "${xray_shortIds_vrv}"
          ],
          "privateKey": "${xray_privateKey_vrv}",
          "serverNames": [
            "$DOMAIN"
          ],
          "limitFallbackUpload": {
            "afterBytes": 0,
            "bytesPerSec": 65536,
            "burstBytesPerSec": 0
          },
          "limitFallbackDownload": {
            "afterBytes": 5242880,
            "bytesPerSec": 262144,
            "burstBytesPerSec": 2097152
          }
        }
      }
    },
	{
      "tag": "vsXHTTPrty",
      "port": 3333,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${xray_uuid_vrv}"
          }
        ],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "auto",
		  "path": "/${path_xhttp}"
        },
        "security": "none",
        "sockopt": {
          "acceptProxyProtocol": true
        }
      }
    },
    {
      "tag": "vsRAWrty",
      "port": 4444,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${xray_uuid_vrv}"
          }
        ],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "raw",
        "rawSettings": {
          "acceptProxyProtocol": true,
          "header": {
            "type": "http",
            "request": {
              "path": [
                "/${path_xhttp}44"
              ]
            }
          }
		},
        "security": "none"
      }
    },	
	{
      "tag": "ShadowSocks2022",
      "port": 8443,
      "listen": "0.0.0.0",
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-chacha20-poly1305",
        "password": "${xray_sspasw_vrv}",
        "network": "tcp,udp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    },
	{
      "tag": "socks5",
      "port": 10443,
      "listen": "0.0.0.0",
      "protocol": "mixed",
      "settings": {
        "ip": "0.0.0.0",
        "udp": true,
        "auth": "password",
        "accounts": [
          {
			"user": "${socksUser}",
            "pass": "${socksPasw}"
            
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "ForceIPv4"
      }
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    },
	{
	  "tag": "warp",
	  "protocol": "socks",
	  "settings": {
		"servers": [
		  {
			"address": "127.0.0.1",
			"port": 40000
		  }
		]
	  }
	}
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      },
      {
        "domain": [
          "geosite:category-ads",
          "geosite:win-spy",
          "geosite:private"
        ],
        "outboundTag": "block"
      },
	{
	  "outboundTag": "direct",
	  "domain": ["geosite:google-gemini","geosite:category-ru"]
	}
    ],
    "domainStrategy": "IPIfNonMatch"
  }
}

EOF

# Создаем JSON конфигурацию клиента
#!/bin/bash

# 1. Функция-шаблон (содержит повторяющуюся часть: Log, DNS, Routing, Inbounds)
print_config() {
  local PROXY_OUTBOUND="$1"
  local REMARK="$2"

  cat << TPL
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "servers": [
      "https://8.8.4.4/dns-query",
      "https://8.8.8.8/dns-query",
      "https://1.1.1.1/dns-query"
    ],
    "queryStrategy": "UseIPv4"
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "domain": [
          "geosite:category-ads",
          "geosite:win-spy"
        ],
        "outboundTag": "block"
      },
      {
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "direct"
      },
      {
        "domain": [
          "geosite:private",
          "geosite:apple",
          "geosite:apple-pki",
          "geosite:huawei",
          "geosite:xiaomi",
          "geosite:category-android-app-download",
          "geosite:f-droid",
          "geosite:yandex",
          "geosite:vk",
          "geosite:microsoft",
          "geosite:win-update",
          "geosite:win-extra",
          "geosite:google-play",
          "geosite:steam",
          "geosite:category-ru"
        ],
        "outboundTag": "direct"
      },
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "direct"
      },
      {
        "ip": [
          "geoip:!ru"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:discord",
          "geosite:youtube",
          "geosite:tiktok",
          "geosite:signal"
        ],
        "outboundTag": "proxy"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "socks-in",
      "protocol": "socks",
      "listen": "127.0.0.1",
      "port": 10808,
      "settings": {
        "udp": true
      }
    },
    {
      "tag": "socks-sb",
      "protocol": "socks",
      "listen": "127.0.0.1",
      "port": 2080,
      "settings": {
        "udp": true
      }
    },
    {
      "tag": "http-in",
      "protocol": "http",
      "listen": "127.0.0.1",
      "port": 10809
    }
  ],
  "outbounds": [
      $PROXY_OUTBOUND,
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "remarks": "$REMARK"
}
TPL
}

# 2. Определяем уникальные настройки (Outbounds)

# --- Config 1: VLESS Reality + Vision ---
OUT_REALITY_VISION='{
  "mux": { "concurrency": -1, "enabled": false },
  "tag": "proxy",
  "protocol": "vless",
  "settings": {
    "vnext": [{
      "address": "$DOMAIN",
      "port": 443,
      "users": [{ "id": "${xray_uuid_vrv}", "flow": "xtls-rprx-vision", "encryption": "none" }]
    }]
  },
  "streamSettings": {
    "network": "raw",
    "security": "reality",
    "realitySettings": {
      "show": false, "fingerprint": "chrome", "serverName": "$DOMAIN",
      "password": "${xray_publicKey_vrv}", "shortId": "${xray_shortIds_vrv}", "spiderX": "/"
    }
  }
}'

# --- Config 2: VLESS Reality + XHTTP (с Extra настройками) ---
OUT_REALITY_XHTTP='{
  "mux": { "concurrency": -1, "enabled": false },
  "tag": "proxy",
  "protocol": "vless",
  "settings": {
    "vnext": [{
      "address": "$DOMAIN",
      "port": 443,
      "users": [{ "id": "${xray_uuid_vrv}", "encryption": "none" }]
    }]
  },
  "streamSettings": {
    "network": "xhttp",
    "security": "reality",
    "xhttpSettings": {
      "mode": "auto",
      "path": "/${path_xhttp}",
      "extra": {
        "noGRPCHeader": false,
        "scMaxEachPostBytes": 1500000,
        "scMinPostsIntervalMs": 20,
        "scStreamUpServerSecs": "60-240",
        "xPaddingBytes": "400-800",
        "xmux": {
          "cMaxReuseTimes": "1000-3000",
          "hKeepAlivePeriod": 0,
          "hMaxRequestTimes": "400-700",
          "hMaxReusableSecs": "1200-1800",
          "maxConcurrency": "3-5",
          "maxConnections": 0
        }
      }
    },
    "realitySettings": {
      "show": false, "fingerprint": "chrome", "serverName": "$DOMAIN",
      "password": "${xray_publicKey_vrv}", "shortId": "${xray_shortIds_vrv}", "spiderX": "/"
    }
  }
}'

# --- Config 3: VLESS Reality usual MUX---
OUT_REALITY_usual='{
  "mux": { "concurrency": 8, "enabled": true,
    "xudpConcurrency": 16,
    "xudpProxyUDP443": "reject" },
  "tag": "proxy",
  "protocol": "vless",
  "settings": {
    "vnext": [{
      "address": "$DOMAIN",
      "port": 443,
      "users": [{ "id": "${xray_uuid_vrv}", "flow": "", "encryption": "none" }]
    }]
  },
  "streamSettings": {
    "network": "raw",
    "security": "reality",
    "realitySettings": {
      "show": false, "fingerprint": "chrome", "serverName": "$DOMAIN",
      "password": "${xray_publicKey_vrv}", "shortId": "${xray_shortIds_vrv}", "spiderX": "/"
    },
	"rawSettings": {
		"header": {
			"request": {
				"path": [
					"/${path_xhttp}44"
				]
			},
			"type": "http"
		}
	}
  }
}'

# --- Config 4: Shadowsocks 2022 (Port 8443, Chacha20) ---
OUT_SS='{
  "mux": { "concurrency": -1, "enabled": false },
  "tag": "proxy",
  "protocol": "shadowsocks",
  "settings": {
    "servers": [{
      "port": 8443,
      "method": "2022-blake3-chacha20-poly1305",
      "address": "$DOMAIN",
      "password": "${xray_sspasw_vrv}"
    }]
  }
}'

# 3. Сборка JSON массива и сохранение в файл
(
  echo "["
  print_config "$OUT_REALITY_VISION" "🇪🇺 VlessRAWrealityXTLS"
  echo ","
  print_config "$OUT_REALITY_XHTTP"  "🇪🇺 vlessXHTTPrealityEXTRA"
  echo ","
  print_config "$OUT_REALITY_usual"  "🇪🇺 vlessRAWrealityMUX"
  echo ","
  print_config "$OUT_SS"             "🇪🇺 ShadowS2022blake3"
  echo "]"
) | envsubst > "$WEB_PATH/$path_subpage.json"

# Перезапуск Xray
echo "Перезапуск Xray..."
systemctl restart xray
echo -e "Готово!\n"

# Формирование ссылок
subPageLink="https://$DOMAIN/$path_subpage.json"

# Формирование ссылок
link1="vless://${xray_uuid_vrv}@$DOMAIN:443?security=reality&type=tcp&headerType=&path=&host=&flow=xtls-rprx-vision&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessRAWrealityXTLS-autoXRAY"

link2="vless://${xray_uuid_vrv}@$DOMAIN:443?security=reality&type=xhttp&headerType=&path=%2F$path_xhttp&host=&mode=auto&extra=%7B%22xmux%22%3A%7B%22cMaxReuseTimes%22%3A%221000-3000%22%2C%22maxConcurrency%22%3A%223-5%22%2C%22maxConnections%22%3A0%2C%22hKeepAlivePeriod%22%3A0%2C%22hMaxRequestTimes%22%3A%22400-700%22%2C%22hMaxReusableSecs%22%3A%221200-1800%22%7D%2C%22headers%22%3A%7B%7D%2C%22noGRPCHeader%22%3Afalse%2C%22xPaddingBytes%22%3A%22400-800%22%2C%22scMaxEachPostBytes%22%3A1500000%2C%22scMinPostsIntervalMs%22%3A20%2C%22scStreamUpServerSecs%22%3A%2260-240%22%7D&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessXHTTPrealityEXTRA-autoXRAY"

link3="vless://${xray_uuid_vrv}@$DOMAIN:443?security=reality&type=tcp&headerType=http&path=%2F${path_xhttp}44&host=&flow=&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessRAWrealityNOmux-autoXRAY"

ENCODED_STRING=$(echo -n "2022-blake3-chacha20-poly1305:${xray_sspasw_vrv}" | base64 -w 0)
linkSS="ss://$ENCODED_STRING@${DOMAIN}:8443#Shadowsocks2022-autoXRAY"


configListLink="https://$DOMAIN/$path_subpage.html"

# Создаем html файл с конфигами
cat > "$WEB_PATH/$path_subpage.html" <<EOF
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta name="robots" content="noindex,nofollow,noarchive,nosnippet,noimageindex">
<title>AutoXRAY configs</title>
<style>
    body { font-family: monospace; background: #121212; color: #e0e0e0; padding: 10px; max-width: 800px; margin: 0 auto; }
    h3 { color: #82aaff; border-bottom: 1px solid #333; padding-bottom: 10px; margin-top: 30px; }
    h2 { color: #c3e88d; border-top: 2px solid #333; padding-top: 20px; margin-top: 0; }
    
    /* Стили для строки с конфигом */
    .config-row {
        background: #1e1e1e;
        border: 1px solid #333;
        border-radius: 8px;
        padding: 10px;
        display: flex;
        align-items: center;
        gap: 10px;
        margin-bottom: 10px;
    }
    
    /* Контейнер для текста ссылки */
    .config-code {
        flex: 1;
        white-space: nowrap;
        overflow-x: auto;
        padding: 10px;
        background: #121212;
        border-radius: 4px;
        color: #c3e88d;
        font-size: 14px;
        scrollbar-width: thin;
        scrollbar-color: #333 #121212;
    }

    /* Блок всех конфигов (многострочный с прокруткой) */
    #cAll {
        white-space: pre-wrap;
        word-break: break-all;
        max-height: 90px;
        overflow-y: auto;
        font-size: 12px;
    }
    
    /* Кнопка копирования */
    .copy-btn {
        background: #2c2c2c;
        color: #e0e0e0;
        border: 1px solid #555;
        padding: 10px 15px;
        border-radius: 6px;
        cursor: pointer;
        font-weight: bold;
        transition: all 0.2s;
        min-width: 100px;
        height: 100%;
        align-self: flex-start;
    }
    .copy-btn:hover {
        background: #c3e88d;
        color: #121212;
        border-color: #c3e88d;
    }
    .copy-btn:active {
        transform: translateY(2px);
    }

    /* Кнопки ссылок (HAPP, TG) */
    .btn-group { display: flex; flex-wrap: wrap; gap: 15px; margin-top: 15px; margin-bottom: 25px; }
    .btn { flex: 1; min-width: 250px; background-color: #2c2c2c; color: #c3e88d; border: 1px solid #c3e88d; padding: 15px; text-align: center; border-radius: 8px; text-decoration: none; font-weight: 700; transition: all 0.3s ease; display: flex; align-items: center; justify-content: center; }
    .btn:hover { background-color: #c3e88d; color: #121212; cursor: pointer; box-shadow: 0 0 10px rgba(195,232,141,.3); }
    .btn.download { border-color: #82aaff; color: #82aaff; }
    .btn.download:hover { background-color: #82aaff; color: #121212; box-shadow: 0 0 10px rgba(130,170,255,.3); }
    
    /* Спец цвет для телеграма */
    .btn.tg { border-color: #2AABEE; color: #2AABEE; }
    .btn.tg:hover { background-color: #2AABEE; color: #fff; box-shadow: 0 0 10px rgba(42,171,238,.3); }
</style>
<script>
    function copyText(elementId, btnElement) {
        const text = document.getElementById(elementId).innerText;
        navigator.clipboard.writeText(text).then(() => {
            const originalText = btnElement.innerText;
            btnElement.innerText = "Скопировано!";
            btnElement.style.background = "#c3e88d";
            btnElement.style.color = "#121212";
            setTimeout(() => {
                btnElement.innerText = originalText;
                btnElement.style.background = "";
                btnElement.style.color = "";
            }, 2000);
        }).catch(err => {
            console.error('Ошибка:', err);
        });
    }
</script>
</head>
<body>

<h2>📂 Ссылка на подписку (готовый конфиг клиента с роутингом)</h2>
<div class="config-row">
    <div class="config-code" id="subLink">$subPageLink</div>
    <button class="copy-btn" onclick="copyText('subLink', this)">Копировать</button>
</div>

<h3>📱 Приложение HAPP (Windows/Android/iOS/MAC/Linux)</h3>
<p>Маршрутизацию нужно выключить, она тут встроенная. По умолчанию она выключена - включатся, если вы пользовались сторонними сервисами.</p>
<div class="btn-group">
    <a href="happ://add/$subPageLink" class="btn">⚡ Автодобавление в HAPP</a>
    <a href="https://www.happ.su/main/ru" target="_blank" class="btn download">⬇️ Скачать HAPP</a>
</div>

<h3>➡️ VLESS RAW Reality xtls-rprx-vision</h3>
<div class="config-row">
    <div class="config-code" id="c1">$link1</div>
    <button class="copy-btn" onclick="copyText('c1', this)">Копировать</button>
</div>

<h3>➡️ VLESS XHTTP Reality EXTRA - конфиг для роутера</h3>
<div class="config-row">
    <div class="config-code" id="c2">$link2</div>
    <button class="copy-btn" onclick="copyText('c2', this)">Копировать</button>
</div>

<h3>➡️ VLESS RAW Reality noMUX</h3>
<div class="config-row">
    <div class="config-code" id="c3">$link3</div>
    <button class="copy-btn" onclick="copyText('c3', this)">Копировать</button>
</div>

<h3>➡️ Shadowsocks2022blake3 - новый и быстрый</h3>
<div class="config-row">
    <div class="config-code" id="c4">$linkSS</div>
    <button class="copy-btn" onclick="copyText('c4', this)">Копировать</button>
</div>

<h3>➡️ Socks5 proxy (используйте для ТГ)</h3>
<!-- Поле для копирования данных -->
<div class="config-row">
    <div class="config-code" id="sockCreds">server=$DOMAIN port=10443 user=${socksUser} pass=${socksPasw}</div>
    <button class="copy-btn" onclick="copyText('sockCreds', this)">Копировать</button>
</div>
<!-- Кнопка добавления -->
<div class="btn-group">
    <a href="https://t.me/socks?server=$DOMAIN&port=10443&user=${socksUser}&pass=${socksPasw}" target="_blank" class="btn tg">✈️ Автодобавление в Telegram</a>
</div>

<h2>💠 Все конфиги вместе</h2>
<div class="config-row">
    <div class="config-code" id="cAll">$link1<br>$link2<br>$link3<br>$linkSS</div>
    <button class="copy-btn" onclick="copyText('cAll', this)">Копировать</button>
</div>

</body>
</html>
EOF

echo -e "

Ваш конфиг vless RAW reality XTLS:
$link1

Ваш конфиг vless XHTTP reality EXTRA:
$link2

Ваш конфиг vless RAW reality noMUX:
$link3

Ваш конфиг Shadowsocks 2022-blake3-chacha20-poly1305:
$linkSS

Ваша страничка подписки:
\033[32m$subPageLink\033[0m

Ссылка на сохраненные конфиги: 
\033[32m$configListLink\033[0m

Скопируйте подписку в специализированное приложение:
- iOS: Happ или v2RayTun или v2rayN
- Android: Happ или v2RayTun или v2rayNG
- Windows: конфиги Happ или winLoadXRAY или v2rayN
	для vless v2RayTun или Throne

Открыт локальный socks5 на порту 10808, 2080 и http на 10809.

Поддержать автора: https://github.com/xVRVx/autoXRAY
"
