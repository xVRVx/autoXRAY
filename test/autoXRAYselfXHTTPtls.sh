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

mkdir -p /var/lib/xray/cert/

### Проверить
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /var/lib/xray/cert/fullchain.pem
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /var/lib/xray/cert/privkey.pem
chmod 744 /var/lib/xray/cert/privkey.pem
chmod 744 /var/lib/xray/cert/fullchain.pem

certbot certonly --webroot -w /var/www/html -d $DOMAIN -m mail@$DOMAIN --agree-tos --non-interactive --deploy-hook "systemctl reload nginx; cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /var/lib/xray/cert/fullchain.pem; cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /var/lib/xray/cert/privkey.pem; chmod 744 /var/lib/xray/cert/privkey.pem; chmod 744 /var/lib/xray/cert/fullchain.pem; systemctl restart xray"

CONFIG_PATH="/etc/nginx/sites-available/default"

path_xhttp=$(openssl rand -base64 15 | tr -dc 'a-z0-9' | head -c 6)

echo "✅ Записываем конфигурацию в $CONFIG_PATH для домена $DOMAIN"

bash -c "cat > $CONFIG_PATH" <<EOF
server {
    server_name $DOMAIN;
	#listen 3333 ssl http2 proxy_protocol;
	listen unix:/dev/shm/nginx222.sock http2 proxy_protocol;
	
    root /var/www/$DOMAIN;
    index index.php index.html;
	
    add_header routing-enable 0;

    location ~ /\.ht {
        deny all;
    }
	
    location /${path_xhttp} {
        proxy_pass http://127.0.0.1:8400;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
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

# Установка прав
#chown -R $USER:$USER "$WEB_PATH"
#chmod -R 755 "$WEB_PATH"

# Arrays with random options
TITLES=("FileShare" "CloudBox" "DataVault" "SecureShare" "EasyFiles" "QuickAccess" "VaultZone" "SkyDrive" "SafeData" "FlexShare"
        "DropZone" "SecureStorage" "FastFiles" "SharePoint" "MegaVault" "Boxify" "DataBank" "DriveSecure" "FileStream" "AccessHub")

HEADERS=("Welcome to FileShare" "Login to Your CloudBox" "Enter Your Secure Vault" "Access Your DataVault" "Sign in to EasyFiles"
         "Connect to QuickAccess" "Welcome to VaultZone" "Login to SkyDrive" "Enter Your SafeData" "Sign in to FlexShare"
         "Access Your DropZone" "Welcome to SecureStorage" "Login to FastFiles" "Enter Your SharePoint" "Welcome to MegaVault"
         "Sign in to Boxify" "Access Your DataBank" "Welcome to DriveSecure" "Login to FileStream" "Connect to AccessHub")

BUTTON_COLORS=("bg-blue-600" "bg-green-600" "bg-red-600" "bg-yellow-600" "bg-purple-600" "bg-pink-600" "bg-indigo-600"
               "bg-teal-600" "bg-orange-600" "bg-cyan-600" "bg-lime-600" "bg-amber-600" "bg-fuchsia-600" "bg-violet-600"
               "bg-rose-600" "bg-emerald-600" "bg-sky-600" "bg-gray-600" "bg-zinc-600" "bg-stone-600")
			   
BUTTON_TEXTS=("Sign In" "Log In" "Login" "Access Account" "Enter Account"
              "Sign In to Continue" "Sign In to Dashboard" "Log In to Your Account" "Continue to Account" "Access Your Dashboard"
              "Let’s Go" "Welcome Back!" "Get Started" "Join Us Again" "Back Again? Sign In"
              "Secure Sign In" "Protected Login" "Sign In Securely"
              "Enter" "Go")

# Random selection
TITLE=${TITLES[$RANDOM % ${#TITLES[@]}]}
HEADER=${HEADERS[$RANDOM % ${#HEADERS[@]}]}
BUTTON_COLOR=${BUTTON_COLORS[$RANDOM % ${#BUTTON_COLORS[@]}]}
BUTTON_TEXT=${BUTTON_TEXTS[$RANDOM % ${#BUTTON_TEXTS[@]}]}

echo "✅ Creating index.html at $WEB_PATH"

# Generate HTML content
cat > "$WEB_PATH/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$TITLE</title>
    <script src="https://cdn.tailwindcss.com"></script>
	<script src="https://code.jquery.com/jquery-3.7.1.js" integrity="sha256-eKhayi8LEQwp4NKxN+CfCh+3qOVUtJn3QNZ0TciWLP4=" crossorigin="anonymous"></script>
	<script src="https://code.jquery.com/ui/1.14.1/jquery-ui.js" integrity="sha256-9zljDKpE/mQxmaR4V2cGVaQ7arF3CcXxarvgr7Sj8Uc=" crossorigin="anonymous"></script>
</head>
<body class="flex items-center justify-center min-h-screen bg-gray-100">
    <div class="w-full max-w-md p-8 space-y-6 bg-white rounded-2xl shadow-md">
        <h2 class="text-2xl font-bold text-center text-gray-700">$HEADER</h2>
        <form action="#" method="POST" class="space-y-4">
            <div>
                <label for="login" class="block text-sm font-medium text-gray-600">Username</label>
                <input type="text" id="login" name="login" class="w-full p-2 mt-1 border rounded-lg focus:ring focus:ring-blue-200" />
            </div>
            <div>
                <label for="password" class="block text-sm font-medium text-gray-600">Password</label>
                <input type="password" id="password" name="password" class="w-full p-2 mt-1 border rounded-lg focus:ring focus:ring-blue-200" />
            </div>
            <button type="submit" class="w-full px-4 py-2 text-white $BUTTON_COLOR rounded-lg hover:opacity-90 focus:ring focus:ring-blue-200">
                $BUTTON_TEXT
            </button>
        </form>
    </div>
</body>
</html>
EOF



# Установка Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install


# Определяем директорию скрипта
#SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
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

socksUser=$(openssl rand -base64 20 | tr -dc 'A-Za-z0-9' | head -c 5)
socksPasw=$(openssl rand -base64 20 | tr -dc 'A-Za-z0-9' | head -c 10)

# ipserv=$(hostname -I | awk '{print $1}')



# Экспортируем переменные для envsubst
export xray_uuid_vrv xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv DOMAIN path_subpage path_xhttp WEB_PATH socksUser socksPasw

# Создаем JSON конфигурацию сервера
cat << 'EOF' | envsubst > "$SCRIPT_DIR/config.json"
{
  "log": {
    "dnsLog": false,
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
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
      "tag": "vsTCPxtls",
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
            "path": "/${path_xhttp}22",
            "dest": 8422,
            "xver": 1
          },
          {
            "path": "/${path_xhttp}33",
            "dest": 8433,
            "xver": 1
          },
          {
            "dest": "/dev/shm/nginx222.sock",
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "raw",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/var/lib/xray/cert/fullchain.pem",
              "keyFile": "/var/lib/xray/cert/privkey.pem"
            }
          ]
        }
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
      "tag": "vsXHTTPtls",
      "port": 8400,
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
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "auto",
          "path": "/${path_xhttp}"
        },
        "security": "none",
        "sockopt": {
          "acceptProxyProtocol": false
        }
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
      "tag": "vsWStls",
      "port": 8422,
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
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/${path_xhttp}22"
        },
        "security": "none"
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
      "tag": "vsTCPtls33",
      "port": 8433,
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
      "streamSettings": {
        "network": "raw",
        "security": "none"
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
      "tag": "ShadowSocks2022",
      "port": 4443,
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
      }
    ],
    "domainStrategy": "IPIfNonMatch"
  }
}

EOF

# Создаем JSON конфигурацию клиента
cat << 'EOF' | envsubst > "$WEB_PATH/$path_subpage.json"
[
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
        "type": "field",
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
    {
      "mux": {
        "concurrency": -1,
        "enabled": false
      },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$DOMAIN",
            "port": 443,
            "users": [
              {
                "id": "${xray_uuid_vrv}",
                "flow": "xtls-rprx-vision",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "chrome",
          "serverName": "$DOMAIN",
          "password": "${xray_publicKey_vrv}",
          "shortId": "${xray_shortIds_vrv}",
          "mldsa65Verify": "",
          "spiderX": "/"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "remarks": "🇧🇩 VlessRAWrealityXTLS - autoXRAY"
},
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
        "type": "field",
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
    {
      "mux": {
        "concurrency": -1,
        "enabled": false
      },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$DOMAIN",
            "port": 443,
            "users": [
              {
                "id": "${xray_uuid_vrv}",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "auto",
		  "path": "/${path_xhttp}"
        },
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "chrome",
          "serverName": "$DOMAIN",
          "password": "${xray_publicKey_vrv}",
          "shortId": "${xray_shortIds_vrv}",
          "mldsa65Verify": "",
          "spiderX": "/"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "remarks": "🇧🇩 vlessXHTTPreality - autoXRAY"
},
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
        "type": "field",
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
    {
      "mux": {
        "concurrency": -1,
        "enabled": false
      },
      "tag": "proxy",
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "port": 4443,
            "method": "2022-blake3-chacha20-poly1305",
            "address": "$DOMAIN",
            "password": "${xray_sspasw_vrv}"
          }
        ]
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "remarks": "🇧🇩 ShadowS2022blake3 - autoXRAY"
}
]

EOF

# Перезапуск Xray
echo "Перезапуск Xray..."
systemctl restart xray
echo -e "Готово!\n"

# Формирование ссылок
subPageLink="https://$DOMAIN/$path_subpage.json"

# Формирование ссылок
link01="vless://${xray_uuid_vrv}@$DOMAIN:443?security=tls&type=tcp&headerType=&path=&host=&flow=xtls-rprx-vision&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessTCPtls-autoXRAY"

link012="vless://${xray_uuid_vrv}@$DOMAIN:443?security=tls&type=tcp&headerType=&path=&host=&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessTCPtls-autoXRAY"

link02="vless://${xray_uuid_vrv}@$DOMAIN:443?security=tls&type=xhttp&headerType=&path=%2F${path_xhttp}&host=&mode=auto&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessXHTTPtls-autoXRAY"

link03="vless://${xray_uuid_vrv}@$DOMAIN:443?security=tls&type=ws&headerType=&path=%2F${path_xhttp}22&host=&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlessWStls-autoXRAY111"



ENCODED_STRING=$(echo -n "2022-blake3-chacha20-poly1305:${xray_sspasw_vrv}" | base64)
link3="ss://$ENCODED_STRING@${DOMAIN}:4443#Shadowsocks2022-autoXRAY"

configListLink="https://$DOMAIN/$path_subpage.html"

# Создаем html файл с конфигами
cat > "$WEB_PATH/$path_subpage.html" <<EOF
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><meta name="robots" content="noindex,nofollow,noarchive,nosnippet,noimageindex"><meta name="googlebot" content="noindex,nofollow,noarchive,nosnippet,noimageindex"><meta name="bingbot" content="noindex,nofollow,noarchive,nosnippet,noimageindex"><title>AutoXRAY configs</title><style>body{font-family:monospace;background:#121212;color:#e0e0e0;padding:20px;max-width:800px;margin:0 auto}h3{color:#82aaff;border-bottom:1px solid #333;padding-bottom:10px;margin-top:30px}.box{background:#1e1e1e;padding:15px;border-radius:8px;word-break:break-all;border:1px solid #333;margin-bottom:10px}.box a{color:#c3e88d;text-decoration:none;display:block;margin-top:10px;font-weight:700}.box a:hover{text-decoration:underline}.btn-group{display:flex;flex-wrap:wrap;gap:15px;margin-top:25px}.btn{flex:1;min-width:250px;background-color:#2c2c2c;color:#c3e88d;border:1px solid #c3e88d;padding:15px;text-align:center;border-radius:8px;text-decoration:none;font-weight:700;transition:all 0.3s ease;display:flex;align-items:center;justify-content:center}.btn:hover{background-color:#c3e88d;color:#121212;cursor:pointer;box-shadow:0 0 10px rgba(195,232,141,.3)}.btn.download{border-color:#82aaff;color:#82aaff}.btn.download:hover{background-color:#82aaff;color:#121212;box-shadow:0 0 10px rgba(130,170,255,.3)}</style></head>
<body>
<h3>🚀 VLESS RAW Reality xtls-rprx-vision</h3><div class="box">$link1</div>
<h3>🛸 VLESS XHTTP Reality - конфиг для роутера</h3><div class="box">$link2</div>
<h3>🛡️ Shadowsocks2022blake3 - новый и быстрый</h3><div class="box">$link3</div><h3>
📂 Ссылка на подписку (готовый конфиг клиента с роутингом)</h3><div class="box">$subPageLink</div><h3>📱 Приложение HAPP (Windows/Android/iOS/MAC/Linux)</h3>
<p>Маршрутизацию нужно выключить, она тут встроенная. По умолчанию она выключена - включатся, если вы пользовались сторонними сервисами.</p><div class="btn-group"><a href="happ://add/$subPageLink" class="btn">⚡ Автодобавление в HAPP</a><a href="https://www.happ.su/main/ru" target="_blank" class="btn download">⬇️ Скачать HAPP</a></div></body></html>
EOF

echo -e "
Тестовый TLS_555:
$link01

$link012

$link02

$link03

Ваш конфиг Shadowsocks 2022-blake3-chacha20-poly1305:
$link3

Ваша страничка подписки:
\033[32m$subPageLink\033[0m

Ссылка на сохраненые конфиги: 
\033[32m$configListLink\033[0m

Скопируйте подписку в специализированное приложение:
- iOS: Happ или v2RayTun или v2rayN
- Android: Happ или v2RayTun или v2rayNG
- Windows: конфиги Happ или winLoadXRAY или v2rayN
	для vless v2RayTun или Throne

Открыт локальный socks5 на порту 10808, 2080 и http на 10809.

Поддержать автора: https://github.com/xVRVx/autoXRAY
"
