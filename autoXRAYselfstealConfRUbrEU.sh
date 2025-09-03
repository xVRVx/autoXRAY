#!/bin/bash

DOMAIN=$1

vless_url=$2

if [ -z "$DOMAIN" ]; then
    echo "❌ Ошибка: домен не задан."
    exit 1
fi

if [ -z "$vless_url" ]; then
    echo "❌ Ошибка: конфиг vless не задан."
    exit 1
fi

if [[ "$vless_url" != vless://* ]]; then
    echo "❌ Ошибка: Неверный формат vless-ссылки."
    exit 1
fi


# Функция URL-декодинга
urldecode() {
    printf '%b' "${1//%/\\x}"
}
url_body="${vless_url#vless://}"

node_name_enc="${url_body##*#}"
node_nameVL="$(urldecode "$node_name_enc")"

url_body="${url_body%%#*}"

uuidVL="${url_body%@*}"
host_port_query="${url_body#*@}"

addressVL="${host_port_query%%:*}"
restVL="${host_port_query#*:}"
portVL="${restVL%%\?*}"

query_string="${restVL#*\?}"

# Разбор параметров в ассоциативный массив
declare -A params
IFS='&' read -ra pairs <<< "$query_string"
for pair in "${pairs[@]}"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    params["$key"]="$(urldecode "$value")"
done


# Вывод:
echo "== Основное =="
echo "UUID: $uuidVL"
echo "Address: $addressVL"
echo "Port: $portVL"
echo "Node Name: $node_nameVL"

echo ""
echo "== Параметры =="
TYPE="${params[type]}"; echo "TYPE=$TYPE"
FP="${params[fp]}"; echo "FP=$FP"
SNI="${params[sni]}"; echo "SNI=$SNI"
SPX="${params[spx]}"; echo "SPX=$SPX"
PBK="${params[pbk]}"; echo "PBK=$PBK"
SECURITY="${params[security]}"; echo "SECURITY=$SECURITY"
FLOW="${params[flow]}"; echo "FLOW=$FLOW"
SID="${params[sid]}"; echo "SID=$SID"




echo "Обновление и установка необходимых пакетов..."
apt update && apt install -y jq curl dnsutils


LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]')

if [ "$LOCAL_IP" != "$DNS_IP" ]; then
    echo "❌ Ошибка: IP-адрес ($LOCAL_IP) не совпадает с A-записью $DOMAIN ($DNS_IP).
	Правильно укажите одну A-запись для вашего домена в ДНС - $LOCAL_IP"
    exit 1
fi


apt install nginx -y

systemctl enable --now nginx

apt install certbot -y

certbot certonly --webroot -w /var/www/html -d $DOMAIN -m mail@$DOMAIN --agree-tos --non-interactive

CONFIG_PATH="/etc/nginx/sites-available/default"

echo "✅ Записываем конфигурацию в $CONFIG_PATH для домена $DOMAIN"

bash -c "cat > $CONFIG_PATH" <<EOF
server {
    listen 127.0.0.1:3333 ssl http2 proxy_protocol;
    server_name $DOMAIN;

    root /var/www/$DOMAIN;
    index index.php index.html;
	
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers on;

    ssl_session_tickets off;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
	

    location ~ /\.ht {
        deny all;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
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
domains=(www.theregister.com www.20minutes.fr www.dealabs.com www.manomano.fr www.caradisiac.com www.techadvisor.com www.computerworld.com teamdocs.su wikiportal.su docscenter.su www.bing.com github.com tradingview.com)
xray_dest_vrv=${domains[$RANDOM % ${#domains[@]}]}
xray_dest_vrv222=${domains[$RANDOM % ${#domains[@]}]}

key_output=$(xray x25519)
xray_privateKey_vrv=$(echo "$key_output" | awk -F': ' '/PrivateKey/ {print $2}')
xray_publicKey_vrv=$(echo "$key_output" | awk -F': ' '/Password/ {print $2}')

xray_shortIds_vrv=$(openssl rand -hex 8)

xray_sspasw_vrv=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

ipserv=$(hostname -I | awk '{print $1}')



# Экспортируем переменные для envsubst
export xray_uuid_vrv xray_dest_vrv xray_dest_vrv222 xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv DOMAIN path_subpage WEB_PATH TYPE FP SNI SPX PBK SECURITY FLOW SID uuidVL addressVL portVL

# Создаем JSON конфигурацию сервера
cat << 'EOF' | envsubst > "$SCRIPT_DIR/config.json"
{
    "dns": {
        "servers": [
            "https+local://8.8.4.4/dns-query",
            "https+local://8.8.8.8/dns-query",
            "https+local://1.1.1.1/dns-query",
            "localhost"
        ]
    },
    "log": {
        "loglevel": "none",
        "dnsLog": false
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
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
                    "geosite:category-ads"
                ],
                "outboundTag": "block"
            },
			{
				"domain": [
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
				"inboundTag": ["VtcpRself"],
				"outboundTag": "proxy"
			}
        ]
    },
    "inbounds": [
        {
            "tag": "VtcpRself",
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": {
				"flow": "xtls-rprx-vision",
                "clients": [
                    {
                        "flow": "xtls-rprx-vision",
                        "id": "${xray_uuid_vrv}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "raw",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "target": "3333",
                    "xver": 1,
					"SpiderX": "/",
                    "serverNames": [
                        "$DOMAIN"
                    ],
                    "privateKey": "${xray_privateKey_vrv}",
                    "publicKey": "${xray_publicKey_vrv}",
                    "shortIds": [
                        "${xray_shortIds_vrv}"
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
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "tag": "proxy",
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": "$addressVL",
                        "port": $portVL,
                        "users": [
                            {
                                "id": "$uuidVL",
                                "flow": "$FLOW",
                                "encryption": "none",
                                "level": 0
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "$TYPE",
                "security": "$SECURITY",
                "realitySettings": {
                    "serverName": "$SNI",
                    "publicKey": "$PBK",
                    "shortId": "$SID"
                }
            }
        },
		{
		  "protocol": "freedom",
		  "tag": "direct",
		  "settings": {
			"domainStrategy": "ForceIPv4"
		  }
		},
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}

EOF

# Создаем JSON конфигурацию клиента
cat << 'EOF' | envsubst > "$WEB_PATH/$path_subpage.html"
{
    "log": {
        "loglevel": "warning"
    },
    "dns": {
        "servers": [
            "8.8.4.4",
            "8.8.8.8",
            "1.1.1.1",
            "localhost"
        ]
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "domain": [
                    "geosite:category-ads-all",
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
            "tag": "socks-v2rayN",
            "protocol": "socks",
            "listen": "127.0.0.1",
            "port": 1080,
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
                                "encryption": "none",
                                "level": 0
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "raw",
                "security": "reality",
                "realitySettings": {
                    "serverName": "$DOMAIN",
                    "publicKey": "${xray_publicKey_vrv}",
                    "shortId": "${xray_shortIds_vrv}"
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
    ]
}

EOF

# Перезапуск Xray
echo "Перезапуск Xray..."
systemctl restart xray

echo "Готово!
"
# Формирование ссылок
subPageLink="https://$DOMAIN/$path_subpage.html"

# Формирование ссылок
link1="vless://${xray_uuid_vrv}@$DOMAIN:443?security=reality&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#useConfig"
	
echo -e "
Скопируйте подписку в специализированное приложение:
- iOS: Happ или v2rayTun или v2rayN
- Android: Happ или v2rayTun или v2rayNG
- Windows: Happ(alpha) или winLoadXRAY или v2rayN или само ядро Xray


Ваша страничка подписки:
\033[32m$subPageLink\033[0m

Ваш конфиг для роутера:
$link1

Открыт локальный socks5 на порту 10808, 1080, 2080 и http на 10809.

Поддержать автора: https://github.com/xVRVx/autoXRAY
"
