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

    add_header routing-enable 0;
	add_header profile-title "base64:YXV0b1hSQVk=";

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
            "dest": "3333",
            "xver": 0
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
          "xver": 1,
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
        }
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
#!/bin/bash

# 1. Функция-шаблон (содержит повторяющуюся часть: Log, DNS, Routing, Inbounds)
print_config() {
  local PROXY_OUTBOUND="$1"
  local REMARK="$2"

  cat << TPL
  {
    "log": { "loglevel": "warning" },
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
        { "domain": ["geosite:category-ads", "geosite:win-spy"], "outboundTag": "block" },
        { "protocol": ["bittorrent"], "outboundTag": "direct" },
        { "domain": ["geosite:private", "geosite:apple", "geosite:apple-pki", "geosite:huawei", "geosite:xiaomi", "geosite:category-android-app-download", "geosite:f-droid", "geosite:yandex", "geosite:vk", "geosite:microsoft", "geosite:win-update", "geosite:win-extra", "geosite:google-play", "geosite:steam", "geosite:category-ru"], "outboundTag": "direct" },
        { "ip": ["geoip:private"], "outboundTag": "direct" },
        { "type": "field", "ip": ["geoip:!ru"], "outboundTag": "proxy" },
        { "domain": ["geosite:discord", "geosite:youtube", "geosite:tiktok", "geosite:signal"], "outboundTag": "proxy" }
      ]
    },
    "inbounds": [
      { "tag": "socks-in", "protocol": "socks", "listen": "127.0.0.1", "port": 10808, "settings": { "udp": true } },
      { "tag": "socks-sb", "protocol": "socks", "listen": "127.0.0.1", "port": 2080, "settings": { "udp": true } },
      { "tag": "http-in", "protocol": "http", "listen": "127.0.0.1", "port": 10809 }
    ],
    "outbounds": [
      $PROXY_OUTBOUND,
      { "tag": "direct", "protocol": "freedom" },
      { "tag": "block", "protocol": "blackhole" }
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

# --- Config 3: Shadowsocks 2022 (Port 8443, Chacha20) ---
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

ENCODED_STRING=$(echo -n "2022-blake3-chacha20-poly1305:${xray_sspasw_vrv}" | base64)
linkSS="ss://$ENCODED_STRING@${DOMAIN}:8443#Shadowsocks2022-autoXRAY"


configListLink="https://$DOMAIN/$path_subpage.html"

# Создаем html файл с конфигами
cat > "$WEB_PATH/$path_subpage.html" <<EOF
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><meta name="robots" content="noindex,nofollow,noarchive,nosnippet,noimageindex"><meta name="googlebot" content="noindex,nofollow,noarchive,nosnippet,noimageindex"><meta name="bingbot" content="noindex,nofollow,noarchive,nosnippet,noimageindex"><title>AutoXRAY configs</title><style>body{font-family:monospace;background:#121212;color:#e0e0e0;padding:20px;max-width:800px;margin:0 auto}h3{color:#82aaff;border-bottom:1px solid #333;padding-bottom:10px;margin-top:30px}.box{background:#1e1e1e;padding:15px;border-radius:8px;word-break:break-all;border:1px solid #333;margin-bottom:10px}.box a{color:#c3e88d;text-decoration:none;display:block;margin-top:10px;font-weight:700}.box a:hover{text-decoration:underline}.btn-group{display:flex;flex-wrap:wrap;gap:15px;margin-top:25px}.btn{flex:1;min-width:250px;background-color:#2c2c2c;color:#c3e88d;border:1px solid #c3e88d;padding:15px;text-align:center;border-radius:8px;text-decoration:none;font-weight:700;transition:all 0.3s ease;display:flex;align-items:center;justify-content:center}.btn:hover{background-color:#c3e88d;color:#121212;cursor:pointer;box-shadow:0 0 10px rgba(195,232,141,.3)}.btn.download{border-color:#82aaff;color:#82aaff}.btn.download:hover{background-color:#82aaff;color:#121212;box-shadow:0 0 10px rgba(130,170,255,.3)}</style></head>
<body>
<h3>➡️ VLESS RAW Reality xtls-rprx-vision</h3><div class="box">$link1</div>
<h3>➡️ VLESS XHTTP Reality EXTRA - конфиг для роутера</h3><div class="box">$link2</div>
<h3>➡️ Shadowsocks2022blake3 - новый и быстрый</h3><div class="box">$linkSS</div>
<h3>➡️ Socks5 proxy (используйте для ТГ)</h3><div class="box">
server=$DOMAIN port=10443 user=${socksUser} pass=${socksPasw}
<a href="https://t.me/socks?server=$DOMAIN&port=10443&user=${socksUser}&pass=${socksPasw}">Автодобавление в ТГ</a></div><h3>
📂 Ссылка на подписку (готовый конфиг клиента с роутингом)</h3><div class="box">$subPageLink</div><h3>📱 Приложение HAPP (Windows/Android/iOS/MAC/Linux)</h3>
<p>Маршрутизацию нужно выключить, она тут встроенная. По умолчанию она выключена - включается, если вы пользовались сторонними сервисами.</p><div class="btn-group"><a href="happ://add/$subPageLink" class="btn">⚡ Автодобавление в HAPP</a><a href="https://www.happ.su/main/ru" target="_blank" class="btn download">⬇️ Скачать HAPP</a></div></body></html>
EOF

echo -e "

Ваш конфиг vless RAW reality XTLS:
$link1

Ваш конфиг vless XHTTP reality EXTRA:
$link2

Ваш конфиг Shadowsocks 2022-blake3-chacha20-poly1305:
$linkSS

Ваш конфиг socks5 proxy (используйте для ТГ):
server=$DOMAIN port=10443 user=${socksUser} pass=${socksPasw}

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
