#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ скрипту нужны root права ${NC}"; exit 1; }

DOMAIN=$1

vless_url=$2

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Ошибка: домен не задан.${NC}"
    exit 1
fi

if [ -z "$vless_url" ]; then
    echo "${RED}❌ Ошибка: конфиг vless не задан.${NC}"
    exit 1
fi

if [[ "$vless_url" != vless://* ]]; then
    echo "${RED}❌ Ошибка: Неверный формат vless-ссылки.${NC}"
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
echo -e "${YEL}== Основное ==${NC}"
echo "UUID: $uuidVL"
echo "Address: $addressVL"
echo "Port: $portVL"
echo "Node Name: $node_nameVL"

echo ""
echo -e "${YEL}== Параметры ==${NC}"
SECURITY="${params[security]}"; echo "SECURITY=$SECURITY"
TYPE="${params[type]}"; echo "TYPE=$TYPE"
headerType="${params[headerType]}"; echo "headerType=$headerType"
path_url="${params[path]}"; echo "path=$path_url"
host="${params[host]}"; echo "host=$host"
mode="${params[mode]}"; echo "mode=$mode"
extra="${params[extra]}"; echo "extra=$extra"

SNI="${params[sni]}"; echo "SNI=$SNI"
FP="${params[fp]}"; echo "FP=$FP"
PBK="${params[pbk]}"; echo "PBK=$PBK"
SID="${params[sid]}"; echo "SID=$SID"
SPX="${params[spx]}"; echo "SPX=$SPX"


# FLOW="${params[flow]}"; echo "FLOW=$FLOW"



echo "${YEL}Обновление и установка необходимых пакетов...${NC}"
apt-get update && apt-get install curl jq dnsutils openssl nginx certbot -y
systemctl enable --now nginx

LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]')

if [ "$LOCAL_IP" != "$DNS_IP" ]; then
    echo -e "${RED}❌ Внимание: IP-адрес ($LOCAL_IP) не совпадает с A-записью $DOMAIN ($DNS_IP).${NC}"
    echo -e "${YEL}Правильно укажите одну A-запись для вашего домена в ДНС - $LOCAL_IP ${NC}"
    
	read -p "Продолжить на ваш страх и риск? (y/N):" choice

	if [[ ! "$choice" =~ ^[Yy]$ ]]; then
		echo -e "${RED}Выполнение скрипта прервано.${NC}"
		exit 1
	fi
    echo -e "${YEL}Продолжение выполнения скрипта...${NC}"
fi


# Включаем BBR
bbr=$(sysctl -a | grep net.ipv4.tcp_congestion_control)
if [ "$bbr" = "net.ipv4.tcp_congestion_control = bbr" ]; then
    echo -e "${GRN}BBR уже запущен${NC}"
else
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/999-autoXRAY.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/999-autoXRAY.conf
    sysctl --system
    echo -e "${GRN}BBR активирован${NC}"
fi

cat <<EOF > /etc/security/limits.d/99-autoXRAY.conf
*               soft    nofile          65535
*               hard    nofile          65535
root            soft    nofile          65535
root            hard    nofile          65535
EOF
ulimit -n 65535
echo -e "${GRN}Лимиты применены. Текущий ulimit -n: $(ulimit -n) ${NC}"



# Блок CERTBOT - START

# Определяем путь к конфигу nginx
if [ -f /etc/nginx/sites-available/default ]; then
    CONFIG_PATH="/etc/nginx/sites-available/default"
	echo -e "${GRN}Обнаружена стандартная сборка nginx. ${NC}"
elif [ -f /etc/nginx/conf.d/default.conf ]; then
    CONFIG_PATH="/etc/nginx/conf.d/default.conf"
	echo -e "${YEL}Обнаружена нестандартная сборка nginx. Предварительная настройка NGINX для CERTBOT ${NC}"
	mkdir -p /var/www/html

# Записываем временный конфиг
cat <<EOF > "$CONFIG_PATH"
server {
	listen 80 default_server;
	server_name _;

	location /.well-known/acme-challenge/ {
		root /var/www/html;
		allow all;
	}

	location / {
		return 301 https://\$host\$request_uri;
	}
}
EOF
	systemctl reload nginx
else
    echo -e "${RED}Не найден ни один default конфиг nginx${NC}"
    exit 1
fi

certbot certonly --webroot -w /var/www/html \
  -d $DOMAIN \
  -m mail@$DOMAIN \
  --agree-tos --non-interactive \
  --deploy-hook "systemctl reload nginx"

RET=$?

if [ $RET -eq 0 ]; then
  echo -e "\n${GRN}========================================"
  echo    "✅  Команда certbot успешно выполнена"
  echo    "✅  Сертификат https от letsencrypt ПОЛУЧЕН"
  echo    "========================================"
  echo -e "${NC}"
else
  echo -e "\n${RED}========================================"
  echo    "❌  CERTBOT ЗАВЕРШИЛСЯ С ОШИБКОЙ"
  echo    "❌  Сертификат https от letsencrypt НЕ ПОЛУЧЕН!"
  echo    "❌  Смотрите выше логи процесса получения сертификата"
  echo    "❌  Код возврата: $RET"
  echo    "========================================"
  echo -e "${NC}"
  exit 1
fi
# Блок CERTBOT - END

# конфиг nginx
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
	add_header routing "happ://routing/onadd/eyJOYW1lIjoiYXV0b1hSQVkiLCJHbG9iYWxQcm94eSI6InRydWUiLCJSb3V0ZU9yZGVyIjoiYmxvY2stcHJveHktZGlyZWN0IiwiUmVtb3RlRE5TVHlwZSI6IkRvSCIsIlJlbW90ZUROU0RvbWFpbiI6IiIsIlJlbW90ZUROU0lQIjoiIiwiRG9tZXN0aWNETlNUeXBlIjoiRG9IIiwiRG9tZXN0aWNETlNEb21haW4iOiIiLCJEb21lc3RpY0ROU0lQIjoiIiwiR2VvaXB1cmwiOiIiLCJHZW9zaXRldXJsIjoiIiwiTGFzdFVwZGF0ZWQiOiIxNzc1MTMwMDM1IiwiRG5zSG9zdHMiOnt9LCJEaXJlY3RTaXRlcyI6WyJnZW9zaXRlOmNhdGVnb3J5LXJ1IiwiZ2Vvc2l0ZTpwcml2YXRlIl0sIkRpcmVjdElwIjpbImdlb2lwOnByaXZhdGUiXSwiUHJveHlTaXRlcyI6W10sIlByb3h5SXAiOltdLCJCbG9ja1NpdGVzIjpbImdlb3NpdGU6Y2F0ZWdvcnktYWRzIiwiZ2Vvc2l0ZTp3aW4tc3B5Il0sIkJsb2NrSXAiOltdLCJEb21haW5TdHJhdGVneSI6IklQSWZOb25NYXRjaCIsIkZha2VETlMiOiJmYWxzZSIsIlVzZUNodW5rRmlsZXMiOiJmYWxzZSJ9";
	
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

systemctl restart nginx

echo -e "${GRN}✅ Конфигурация nginx обновлена.${NC}

"




# Создание директории
WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"

# Генерируем сайт маскировку
bash -c "$(curl -L https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/gen_page2.sh)" -- $WEB_PATH

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

key_mldsa65=$(xray mldsa65)
seed_mldsa65=$(echo "$key_mldsa65" | awk -F': ' '/Seed/ {print $2}')
verify_mldsa65=$(echo "$key_mldsa65" | awk -F': ' '/Verify/ {print $2}')

xray_shortIds_vrv=$(openssl rand -hex 8)

xray_sspasw_vrv=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

path_xhttp=$(openssl rand -base64 15 | tr -dc 'a-z0-9' | head -c 6)

# ipserv=$(hostname -I | awk '{print $1}')

socksUser=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 6)
socksPasw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)


# Экспортируем переменные для envsubst
export xray_uuid_vrv xray_dest_vrv xray_dest_vrv222 xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv DOMAIN path_subpage WEB_PATH TYPE FP SNI SPX PBK SECURITY FLOW SID mode uuidVL addressVL portVL path_xhttp path_url extra socksUser socksPasw

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
      "tag": "RUbrEUraw",
      "port": ${portVL},
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
      "tag": "RUbrEUxhttp",
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
          "mode": "${mode}",
		  "path": "/${path_xhttp}",
          "acceptProxyProtocol": false
        },
        "security": "none",
        "sockopt": {
          "acceptProxyProtocol": true
        }
      }
    },
	{
      "tag": "RUsocks5",
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
      "mux": {
        "concurrency": -1,
        "enabled": false
      },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "port": ${portVL},
            "users": [
              {
                "id": "$uuidVL",
                "encryption": "none"
              }
            ],
            "address": "$addressVL"
          }
        ]
      },
      "streamSettings": {
        "network": "$TYPE",
        "xhttpSettings": {
         "extra": ${extra},
          "mode": "${mode}",
		  "path": "${path_url}"
        },
        "security": "$SECURITY",
        "realitySettings": {
          "show": false,
          "fingerprint": "$FP",
          "serverName": "$SNI",
		  "password": "$PBK",
		  "shortId": "$SID",
		  "mldsa65Verify": "",
		  "spiderX": "$SPX"
        }
      }
    },
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
        "port": "25",
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
        "domain": [
          "habr.com",
		  "apkmirror.com",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
          "geosite:category-ip-geo-detect"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "testipv6.net",
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
        "inboundTag": [
          "RUbrEUraw","RUbrEUxhttp","RUsocks5"
        ],
        "outboundTag": "proxy"
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
          "habr.com", "apkmirror.com"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:private",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
		  "geosite:category-ip-geo-detect",
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
      "tag": "socks-sb",
      "protocol": "socks",
      "listen": "127.0.0.1",
      "port": 2080,
      "settings": {
        "udp": true
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
      "tag": "http-in",
      "protocol": "http",
      "listen": "127.0.0.1",
      "port": 10809,
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
            "port": ${portVL},
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
        "network": "$TYPE",
        "xhttpSettings": {
         "extra": ${extra},
          "mode": "${mode}",
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
  "remarks": "🇷🇺 Bridge RU-EU vlsXHTTPrty"
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
          "habr.com", "apkmirror.com"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:private",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
		  "geosite:category-ip-geo-detect",
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
      "tag": "socks-sb",
      "protocol": "socks",
      "listen": "127.0.0.1",
      "port": 2080,
      "settings": {
        "udp": true
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
      "tag": "http-in",
      "protocol": "http",
      "listen": "127.0.0.1",
      "port": 10809,
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
            "port": ${portVL},
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
  "remarks": "🇷🇺 Bridge RU-EU vlsRAWrtyXTLS"
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
          "habr.com", "apkmirror.com"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:private",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
		  "geosite:category-ip-geo-detect",
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
            "address": "$addressVL",
            "port": ${portVL},
            "users": [
              {
                "id": "${uuidVL}",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "$TYPE",
        "xhttpSettings": {
         "extra": ${extra},
          "mode": "${mode}",
		  "path": "${path_url}"
        },
        "security": "$SECURITY",
        "realitySettings": {
          "show": false,
          "fingerprint": "$FP",
          "serverName": "$SNI",
		  "password": "$PBK",
		  "shortId": "$SID",
		  "mldsa65Verify": "",
		  "spiderX": "$SPX"
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
  "remarks": "🇪🇺 Direct EU vlsXHTTPrty"
}
]
EOF

systemctl restart xray
echo -e "Перезапуск XRAY"

# Формирование ссылок
subPageLink="https://$DOMAIN/$path_subpage.json"

# Формирование ссылок
link1="vless://${xray_uuid_vrv}@$DOMAIN:${portVL}?security=reality&type=xhttp&headerType=&path=%2F$path_xhttp&host=&mode=${mode}&extra=%7B%22xmux%22%3A%7B%22cMaxReuseTimes%22%3A%221000-3000%22%2C%22maxConcurrency%22%3A%223-5%22%2C%22maxConnections%22%3A0%2C%22hKeepAlivePeriod%22%3A0%2C%22hMaxRequestTimes%22%3A%22400-700%22%2C%22hMaxReusableSecs%22%3A%221200-1800%22%7D%2C%22headers%22%3A%7B%7D%2C%22noGRPCHeader%22%3Afalse%2C%22xPaddingBytes%22%3A%22400-800%22%2C%22scMaxEachPostBytes%22%3A1500000%2C%22scMinPostsIntervalMs%22%3A20%2C%22scStreamUpServerSecs%22%3A%2260-240%22%7D&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlsXHTTPrtyRUbrEU"

link2="vless://${xray_uuid_vrv}@$DOMAIN:${portVL}?security=reality&type=tcp&headerType=&path=&host=&flow=xtls-rprx-vision&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#vlsRAWrtyXTLSRUbrEU"


configListLink="https://$DOMAIN/$path_subpage.html"

CONFIGS_ARRAY=(
    "VLESS XHTTP REALITY RUbrEU|$link1"
    "VLESS RAW REALITY XTLS RUbrEU|$link2"
    "Напрямую через EU|$vless_url"
)
ALL_LINKS_TEXT=""

# --- ЗАПИСЬ HEAD (СТАТИКА, МИНИФИЦИРОВАННЫЕ СТИЛИ И JS) ---
cat > "$WEB_PATH/$path_subpage.html" <<'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta name="robots" content="noindex,nofollow">
<title>autoXRAY bridge configs</title>
<link rel="icon" type="image/svg+xml" href='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDBCRkZGIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTIxIDJsLTIgMm0tNy42MSA3LjYxYTUuNSA1LjUgMCAxIDEtNy43NzggNy43NzggNS41IDUuNSAwIDAgMSA3Ljc3Ny03Ljc3N3ptMCAwTDE1LjUgNy41bTAgMGwzIDNMMjIgN2wtMy0zbS0zLjUgMy41TDE5IDQiLz48L3N2Zz4='>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<style>
body{font-family:monospace;background:#121212;color:#e0e0e0;padding:10px;max-width:900px;margin:0 auto}h2{color:#c3e88d;border-top:2px solid #333;padding-top:20px;margin:15px 0 10px;font-size:18px}.config-row{background:#1e1e1e;border:1px solid #333;border-radius:6px;padding:5px;display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:8px}.config-label{background:#2c2c2c;color:#82aaff;padding:6px 10px;border-radius:4px;font-weight:700;font-size:13px;white-space:nowrap;min-width:140px;text-align:center}.config-code{flex:1;white-space:nowrap;overflow-x:auto;padding:8px;background:#121212;border-radius:4px;color:#c3e88d;font-size:12px;scrollbar-width:none}.config-code::-webkit-scrollbar{display:none}.btn-action{border:1px solid #555;padding:6px 12px;border-radius:4px;cursor:pointer;font-weight:700;font-size:12px;transition:all .2s;height:32px;display:flex;align-items:center;justify-content:center}.copy-btn{background:#333;color:#e0e0e0;min-width:60px}.copy-btn:hover{background:#c3e88d;color:#121212;border-color:#c3e88d}.qr-btn{background:#333;color:#82aaff;border-color:#82aaff;min-width:40px}.qr-btn:hover{background:#82aaff;color:#121212}.btn-group{display:flex;gap:10px;margin:10px 0 20px}.btn{flex:1;background:#2c2c2c;color:#c3e88d;border:1px solid #c3e88d;padding:10px;text-align:center;border-radius:6px;text-decoration:none;font-weight:700;font-size:14px}.btn:hover{background:#c3e88d;color:#121212}.btn.download{border-color:#82aaff;color:#82aaff}.btn.download:hover{background:#82aaff;color:#121212}.btn.tg{border-color:#2AABEE;color:#2AABEE}.btn.tg:hover{background:#2AABEE;color:#fff}.modal-overlay{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.85);z-index:999;justify-content:center;align-items:center;backdrop-filter:blur(3px)}.modal-content{background:#1e1e1e;padding:20px;border-radius:10px;border:1px solid #82aaff;text-align:center}#qrcode{background:#fff;padding:10px;border-radius:6px;margin-bottom:10px}.close-modal-btn{background:#c31e1e;color:#fff;border:none;padding:8px 20px;border-radius:4px;cursor:pointer}@media(max-width:600px){.config-label{width:100%;margin-bottom:2px}.config-code{min-width:100%;order:3}.btn-action{flex:1;order:2}}
</style>
<script>
function copyText(e,t){navigator.clipboard.writeText(document.getElementById(e).innerText).then(()=>{let o=t.innerText;t.innerText="OK",t.style.cssText="background:#c3e88d;color:#121212",setTimeout(()=>{t.innerText=o,t.style.cssText=""},1500)}).catch(e=>console.error(e))}function showQR(e){let t=document.getElementById(e).innerText,o=document.getElementById("qrModal"),n=document.getElementById("qrcode");n.innerHTML="",new QRCode(n,{text:t,width:256,height:256,colorDark:"#000000",colorLight:"#ffffff",correctLevel:QRCode.CorrectLevel.L}),o.style.display="flex"}function closeModal(){document.getElementById("qrModal").style.display="none"}window.onclick=function(e){e.target==document.getElementById("qrModal")&&closeModal()};
</script>
</head><body>
EOF

# --- ЗАПИСЬ BODY (ДИНАМИЧЕСКИЕ ДАННЫЕ) ---
cat >> "$WEB_PATH/$path_subpage.html" <<EOF

<h2>📂 Ссылка на подписку (готовый конфиг клиента с роутингом)</h2>
<div class="config-row">
    <div class="config-label">Subscription</div>
    <div class="config-code" id="subLink">$subPageLink</div>
    <button class="btn-action copy-btn" onclick="copyText('subLink', this)">Copy</button>
    <button class="btn-action qr-btn" onclick="showQR('subLink')">QR</button>
</div>


<h2>📱 Приложение HAPP (Windows/Android/iOS/MAC/Linux)</h2>

<div class="btn-group">
    <a href="happ://add/$subPageLink" class="btn">⚡ Add to HAPP</a>
    <a href="https://www.happ.su/main/ru" target="_blank" class="btn download">⬇️ Download App</a>
</div>
<p>Маршрутизацию нужно выключить, она тут встроенная. По умолчанию она выключена - включается, если вы пользовались сторонними сервисами.</p>


<h2>➡️ Конфиги</h2>
EOF

# Цикл генерации строк конфигов
idx=1
for item in "${CONFIGS_ARRAY[@]}"; do
    title="${item%%|*}"
    link="${item#*|}"
    
    if [ -z "$ALL_LINKS_TEXT" ]; then ALL_LINKS_TEXT="$link"; else ALL_LINKS_TEXT="$ALL_LINKS_TEXT<br>$link"; fi
    
    cat >> "$WEB_PATH/$path_subpage.html" <<EOF
<div class="config-row">
    <div class="config-label">$title</div>
    <div class="config-code" id="c$idx">$link</div>
    <button class="btn-action copy-btn" onclick="copyText('c$idx', this)">Copy</button>
    <button class="btn-action qr-btn" onclick="showQR('c$idx')">QR</button>
</div>
EOF
    ((idx++))
done

# Дописываем Socks5, All links и подвал
cat >> "$WEB_PATH/$path_subpage.html" <<EOF
<div class="config-row">
    <div class="config-label">Мост Socks5 (TG)</div>
    <div class="config-code" id="sock">server=$DOMAIN port=10443 user=${socksUser} pass=${socksPasw}</div>
    <button class="btn-action copy-btn" onclick="copyText('sock', this)">Copy</button>
    <a href="https://t.me/socks?server=$DOMAIN&port=10443&user=${socksUser}&pass=${socksPasw}" target="_blank" class="btn-action qr-btn" title="автодобавление моста в тг" style="text-decoration:none">✈️ Add to TG</a>
</div>

<h2>💠 Все конфиги вместе</h2>
<div class="config-row">
    <div class="config-code" id="cAll" style="max-height:60px;white-space:pre-wrap;word-break:break-all">$ALL_LINKS_TEXT</div>
    <button class="btn-action copy-btn" onclick="copyText('cAll', this)">Copy ALL</button>
    <button class="btn-action qr-btn" onclick="showQR('cAll')">QR</button>
</div>

<div><a style="color:white;margin:40px auto 20px;display:block;text-align:center;" href="https://github.com/xVRVx/autoXRAY">https://github.com/xVRVx/autoXRAY</a></div>

<div id="qrModal" class="modal-overlay"><div class="modal-content"><div id="qrcode"></div><button class="close-modal-btn" onclick="closeModal()">Close</button></div></div>
</body></html>
EOF

# --- ФИНАЛЬНАЯ ПРОВЕРКА ---
echo -e "\n${YEL}=== Финальная проверка статусов ===${NC}"

# Проверка Nginx
if systemctl is-active --quiet nginx; then
    echo -e "Nginx: ${GRN}RUNNING${NC}"
else
    echo -e "Nginx: ${RED}STOPPED/ERROR${NC}"
fi

# Проверка XRAY
if systemctl is-active --quiet xray; then
    echo -e "XRAY: ${GRN}RUNNING${NC}"
else
    echo -e "XRAY: ${RED}STOPPED/ERROR${NC}"
fi


echo -e "
${YEL}VLESS XHTTP REALITY EXTRA (мост RU->EU) ${NC}
$link1

${YEL}VLESS RAW REALITY XTLS (мост RU->EU) ${NC}
$link2

${YEL}Ваша json страничка подписки ${NC}
$subPageLink

${YEL}Ссылка на сохраненные конфиги ${NC}
${GRN}$configListLink ${NC}

Скопируйте подписку в специализированное приложение:
- iOS: Happ или v2RayTun или v2rayN
- Android: Happ или v2RayTun или v2rayNG
- Windows: конфиги Happ или winLoadXRAY или v2rayN
	для vless v2RayTun или Throne

Открыт локальный socks5 на порту 10808, 2080 и http на 10809.

${GRN}Поддержать автора: https://github.com/xVRVx/autoXRAY ${NC}

"
