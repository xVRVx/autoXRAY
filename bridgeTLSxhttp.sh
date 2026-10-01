#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

echo -e "${GRN}Версия: 147-Bridge ${NC}"
sleep 1

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ Скрипту нужны root права!${NC}"; exit 1; }

# Компактная проверка ОС (Debian / Ubuntu)
. /etc/os-release 2>/dev/null
[[ "$ID" =~ ^(debian|ubuntu)$ ]] || { echo -e "${RED}❌ Ошибка: поддерживаются только Debian и Ubuntu!${NC}"; exit 1; }
[[ "$ID" == "ubuntu" ]] && echo -e "${YEL}⚠️ Внимание: запуск на Ubuntu. Рекомендованная система: Debian 12/13.${NC}"

DOMAIN=$1
shift
VLESS_URLS=("$@")

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Ошибка: домен не задан.${NC}"
    exit 1
fi

if [ ${#VLESS_URLS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Ошибка: конфиги vless не заданы. Укажите хотя бы одну vless:// ссылку.${NC}"
    exit 1
fi

urldecode() {
    printf '%b' "${1//%/\\x}"
}

COUNT=${#VLESS_URLS[@]}
echo -e "${GRN}Обнаружено $COUNT vless ссылок для моста!${NC}"

declare -a NODE_UUID NODE_ADDR NODE_PORT NODE_NAME NODE_TYPE NODE_SEC NODE_FP NODE_SNI NODE_MODE NODE_PATH NODE_EXTRA NODE_ALPN
declare -a BRIDGE_UUID

# Базовый UUID: 3-я группа байт зарезервирована под vlessRoute (0000)
SERVER_UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
g1="${SERVER_UUID:0:8}"
g2="${SERVER_UUID:9:4}"
g4="${SERVER_UUID:19:4}"
g5="${SERVER_UUID:24:12}"

BASE_BRIDGE_UUID="${g1}-${g2}-0000-${g4}-${g5}"

for (( i=0; i<COUNT; i++ )); do
    url="${VLESS_URLS[$i]}"
    if [[ "$url" != vless://* ]]; then
        echo -e "${RED}❌ Ошибка: Неверный формат vless-ссылки: $url${NC}"
        exit 1
    fi

    url_body="${url#vless://}"
    node_name_enc="${url_body##*#}"
    NODE_NAME[$i]="$(urldecode "$node_name_enc")"

    url_body="${url_body%%#*}"
    NODE_UUID[$i]="${url_body%@*}"
    host_port_query="${url_body#*@}"

    NODE_ADDR[$i]="${host_port_query%%:*}"
    restVL="${host_port_query#*:}"
    NODE_PORT[$i]="${restVL%%\?*}"

    query_string="${restVL#*\?}"

    unset params
    declare -A params
    IFS='&' read -ra pairs <<< "$query_string"
    for pair in "${pairs[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        params["$key"]="$(urldecode "$value")"
    done

    NODE_SEC[$i]="${params[security]:-tls}"
    NODE_TYPE[$i]="${params[type]:-xhttp}"
    NODE_PATH[$i]="${params[path]:-/}"
    NODE_MODE[$i]="${params[mode]:-auto}"
    NODE_EXTRA[$i]="${params[extra]}"
    NODE_SNI[$i]="${params[sni]:-${NODE_ADDR[$i]}}"
    NODE_FP[$i]="${params[fp]:-firefox}"
    NODE_ALPN[$i]="${params[alpn]}"

    ROUTE_ID=$((i + 1))
    HEX_ROUTE_ID=$(printf "%04x" $ROUTE_ID)
    BRIDGE_UUID[$i]="${g1}-${g2}-${HEX_ROUTE_ID}-${g4}-${g5}"
done

SERVER_PORT=443

KEYRING_PKG=$([ "$ID" = "ubuntu" ] && echo "ubuntu-keyring" || echo "debian-archive-keyring")

echo -e "${YEL}Подготовка официального репозитория Nginx для $ID ($VERSION_CODENAME)...${NC}"
apt-get update && apt-get install -y curl gnupg2 ca-certificates lsb-release $KEYRING_PKG jq dnsutils openssl wget tar socat cron gettext-base

curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor --yes -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/$ID $VERSION_CODENAME nginx" \
    | tee /etc/apt/sources.list.d/nginx.list >/dev/null

echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | tee /etc/apt/preferences.d/99nginx >/dev/null

apt-get update
apt-get install -y nginx
systemctl enable --now nginx
systemctl enable --now cron

LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]' | head -n 1)

if [ "$LOCAL_IP" != "$DNS_IP" ]; then
    echo -e "${RED}❌ Внимание: IP-адрес ($LOCAL_IP) не совпадает с A-записью $DOMAIN ($DNS_IP).${NC}"
    read -p "Продолжить на ваш страх и риск? (y/N):" choice
	if [[ ! "$choice" =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi

# === ВОПРОСЫ ПОЛЬЗОВАТЕЛЮ ===
read -p "$(echo -e "\n${YEL}Устанавливать Web Proxy для Telegram? (y/n, по умолчанию y): ${NC}")" choice_mtp
choice_mtp=${choice_mtp:-y}
if [[ "$choice_mtp" =~ ^[Yy]$ ]]; then
    INSTALL_MTP=true
    NGINX_web_proxy='    # web proxy
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }'
else
    INSTALL_MTP=false
    NGINX_web_proxy='    location / {
        try_files $uri $uri/ =404;
    }'
fi

echo -e "\n${YEL}Выберите TLS fingerprint для маскировки трафика:${NC}"
echo "1) chrome    3) safari   5) android   7) 360"
echo "2) firefox   4) ios      6) edge      8) qq"
read -p "Введите номер [1-8] (по умолчанию 2 - firefox): " fp_choice

case $fp_choice in
    1) fpBro="chrome" ;;
    2) fpBro="firefox" ;;
    3) fpBro="safari" ;;
    4) fpBro="ios" ;;
    5) fpBro="android" ;;
    6) fpBro="edge" ;;
    7) fpBro="360" ;;
    8) fpBro="qq" ;;
    *) fpBro="firefox" ;;
esac

# BBR, MTU Probing и оптимизация буферов сокетов для моста
cat <<EOF > /etc/sysctl.d/999-autoXRAY.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_mtu_probing=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF
sysctl --system >/dev/null 2>&1

cat <<EOF > /etc/security/limits.d/99-autoXRAY.conf
*       soft    nofile  1048576
*       hard    nofile  1048576
root    soft    nofile  1048576
root    hard    nofile  1048576
EOF
ulimit -n 65535

# Установка Xray
bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v26.9.9

WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"
bash -c "$(curl -sL https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/gen_page3.sh)" -- "$WEB_PATH"

# ================= ACME.SH =================
CONFIG_PATH="/etc/nginx/conf.d/default.conf"
mkdir -p /var/www/html

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
mkdir -p /var/lib/xray/cert/

curl -sL https://get.acme.sh | sh -s email=mail@$DOMAIN
ACME_BIN="$HOME/.acme.sh/acme.sh"

CERT_EXISTS=false
if $ACME_BIN --list | grep -q "$DOMAIN"; then
    CERT_EXISTS=true
fi

if [ "$CERT_EXISTS" = false ]; then
    $ACME_BIN --register-account -m mail@$DOMAIN --server zerossl
    $ACME_BIN --issue -d "$DOMAIN" -w /var/www/html --server zerossl --keylength ec-256
    RET=$?
    if [ $RET -ne 0 ]; then
        $ACME_BIN --issue -d "$DOMAIN" -w /var/www/html --server letsencrypt --keylength ec-256
        RET=$?
    fi
else
    RET=0
fi

if [ $RET -eq 0 ]; then
    $ACME_BIN --install-cert -d "$DOMAIN" --ecc \
      --fullchain-file /var/lib/xray/cert/fullchain.pem \
      --key-file /var/lib/xray/cert/privkey.pem \
      --reloadcmd "chmod 744 /var/lib/xray/cert/privkey.pem /var/lib/xray/cert/fullchain.pem; systemctl reload nginx; systemctl restart xray"
    chmod 744 /var/lib/xray/cert/privkey.pem /var/lib/xray/cert/fullchain.pem
else
    echo -e "${RED}Ошибка выпуска сертификата!${NC}"
    exit 1
fi

path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)
path_xhttp=$(openssl rand -base64 15 | tr -dc 'a-z0-9' | head -c 6)

cat <<EOF > "$CONFIG_PATH"
http2 on;
server_tokens off;

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    server_name $DOMAIN;
    listen unix:/dev/shm/nginx.sock proxy_protocol;

    set_real_ip_from unix:;
    real_ip_header proxy_protocol;

    server_tokens off;
    access_log off;
    error_log /var/log/nginx/error.log crit;

    root /var/www/$DOMAIN;
    index index.html;

    location = /${path_subpage}.html {
        try_files \$uri =404;
    }

    location = /${path_subpage}.json {
        add_header profile-title "base64:YXV0b1hSQVk=";
        try_files \$uri =404;
    }

    # XHTTP endpoint
    location /${path_xhttp} {
        client_max_body_size 0;
        client_body_timeout 1h;
        client_body_buffer_size 4m;

        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        grpc_buffer_size 4m;
        grpc_socket_keepalive on;

        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        grpc_pass grpc://127.0.0.1:3333;
    }

$NGINX_web_proxy

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

SCRIPT_DIR=/usr/local/etc/xray
socksUser=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 6)
socksPasw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)

ROUTING_RULES=""
OUTBOUNDS=""

for (( i=0; i<COUNT; i++ )); do
    ROUTE_ID=$((i + 1))

    # Принудительный маршрут для клиентов, выбравших конкретную ноду
    ROUTING_RULES+="$(cat <<EOF
      { "vlessRoute": "$ROUTE_ID", "outboundTag": "proxy-$i" },
EOF
)"

    EXTRA_VAL="${NODE_EXTRA[$i]}"
    if [ -z "$EXTRA_VAL" ]; then EXTRA_VAL="null"; fi

    OUTBOUNDS+="$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy-$i",
      "protocol": "vless",
      "settings": {
        "vnext":[
          {
            "port": ${NODE_PORT[$i]},
            "users":[ { "id": "${NODE_UUID[$i]}", "encryption": "none" } ],
            "address": "${NODE_ADDR[$i]}"
          }
        ]
      },
      "streamSettings": {
        "network": "${NODE_TYPE[$i]}",
        "xhttpSettings": {
          "extra": $EXTRA_VAL,
          "mode": "${NODE_MODE[$i]}",
          "path": "${NODE_PATH[$i]}"
        },
        "security": "tls",
        "tlsSettings": {
          "serverName": "${NODE_SNI[$i]}",
          "fingerprint": "${NODE_FP[$i]}",
          "alpn": [ "h2", "http/1.1" ]
        }
      }
    },
EOF
)"
done

# Создаем JSON конфигурацию сервера-моста
cat << EOF > "$SCRIPT_DIR/config.json"
{
  "log": {
    "dnsLog": false,
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "burstObservatory": {
    "pingConfig": {
      "timeout": "3s",
      "interval": "40s",
      "sampling": 1,
      "destination": "https://www.gstatic.com/generate_204",
      "connectivity": ""
    },
    "subjectSelector": [
      "proxy"
    ]
  },
  "dns": {
    "servers": [
      {
        "address": "https+local://77.88.8.8/dns-query",
        "domains": [
          "geosite:category-ru",
          "geosite:yandex",
          "geosite:vk",
          "domain:ru",
          "domain:su",
          "domain:xn--p1ai"
        ],
        "skipFallback": true
      },
      "https://8.8.4.4/dns-query",
      "https://8.8.8.8/dns-query",
      "https://1.1.1.1/dns-query"
    ],
    "queryStrategy": "UseIPv4"
  },
  "inbounds": [
    {
      "tag": "RUbrEUtlsVISION",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${BASE_BRIDGE_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": "/dev/shm/nginx.sock",
            "xver": 2
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
          ],
          "minVersion": "1.2",
          "cipherSuites": "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
          "alpn": [ "h2", "http/1.1" ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls", "quic" ]
      }
    },
    {
      "tag": "RUbrEUxhttpTLS",
      "port": 3333,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${BASE_BRIDGE_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "stream-up",
          "path": "/$path_xhttp"
        },
        "security": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls", "quic" ]
      }
    },
    {
      "tag": "RUsocks5",
      "port": 10443,
      "listen": "127.0.0.1",
      "protocol": "mixed",
      "settings": {
        "ip": "127.0.0.1",
        "udp": true,
        "auth": "password",
        "accounts": [
          {
            "user": "$socksUser",
            "pass": "$socksPasw"
          }
        ]
      }
    }
  ],
  "outbounds": [
$OUTBOUNDS
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
    "domainMatcher": "hybrid",
    "domainStrategy": "IPIfNonMatch",
    "balancers": [
      {
        "tag": "Super_Balancer",
        "selector": [
          "proxy"
        ],
        "strategy": {
          "type": "leastLoad",
          "settings": {
            "maxRTT": "1s",
            "expected": $COUNT,
            "baselines": [
              "1s"
            ],
            "tolerance": 0.01
          }
        },
        "fallbackTag": "direct"
      }
    ],
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "port": "25, 135, 137-139, 445",
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
          "testipv6.net",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
          "2ip.io",
          "domain:ru",
          "domain:su",
          "domain:xn--p1ai",
          "geosite:category-ip-geo-detect",
          "geosite:apple",
          "geosite:apple-pki",
          "geosite:f-droid",
          "geosite:yandex",
          "geosite:vk",
          "geosite:category-ru"
        ],
        "outboundTag": "direct"
      },
      {
        "ip": [
          "geoip:ru"
        ],
        "outboundTag": "direct"
      },
$ROUTING_RULES
      {
        "inboundTag": [
          "RUsocks5"
        ],
        "balancerTag": "Super_Balancer"
      },
      {
        "network": "tcp,udp",
        "balancerTag": "Super_Balancer"
      }
    ]
  }
}
EOF

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
      {
        "address": "https+local://77.88.8.8/dns-query",
        "domains": [
          "geosite:category-ru",
          "geosite:yandex",
          "geosite:vk",
          "domain:ru",
          "domain:su",
          "domain:xn--p1ai"
        ],
        "skipFallback": true
      },
      "https://8.8.4.4/dns-query",
      "https://8.8.8.8/dns-query",
      "https://1.1.1.1/dns-query"
    ],
    "queryStrategy": "UseIPv4"
  },
  "routing": {
    "domainMatcher": "hybrid",
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "domain": [ "geosite:category-ads", "geosite:win-spy" ],
        "outboundTag": "block"
      },
      {
        "protocol": [ "bittorrent" ],
        "outboundTag": "direct"
      },
      {
        "domain": [ "habr.com", "apkmirror.com" ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:private",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
          "2ip.io",
          "domain:ru",
          "domain:su",
          "domain:xn--p1ai",
          "geosite:category-ip-geo-detect",
          "geosite:apple",
          "geosite:apple-pki",
          "geosite:f-droid",
          "geosite:yandex",
          "geosite:vk",
          "geosite:category-ru"
        ],
        "outboundTag": "direct"
      },
      {
        "ip": [ "geoip:ru", "geoip:private" ],
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
$PROXY_OUTBOUND,
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" }
  ],
  "remarks": "$REMARK"
}
TPL
}

declare -a CLIENT_JSON_PROFILES
declare -a CONFIGS_ARRAY
ALL_LINKS_TEXT=""

# ================= 1. ПРОФИЛЬ АВТО-БАЛАНСИРОВЩИКА (если нод > 1) =================
if [ $COUNT -gt 1 ]; then
    OUT_AUTO_XHTTP=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "$DOMAIN",
          "port": 443,
          "users":[{ "id": "${BASE_BRIDGE_UUID}", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "alpn": [ "h2" ],
          "fingerprint": "$fpBro"
        },
        "xhttpSettings": {
          "mode": "stream-up",
          "path": "/$path_xhttp",
          "extra": {
            "noGRPCHeader": false,
            "xPaddingBytes": "150-400",
            "scMaxEachPostBytes": 3000000,
            "scMinPostsIntervalMs": 0,
            "scMaxBufferedPosts": 50,
            "scStreamUpServerSecs": "90-180",
            "xmux": {
              "maxConcurrency": "2-4",
              "cMaxReuseTimes": "800-1500",
              "hMaxReusableSecs": "900-1200"
            }
          }
        }
      }
    }
EOF
)

    CLIENT_JSON_PROFILES+=( "$(print_config "$OUT_AUTO_XHTTP" "🇷🇺 RU>EU Автобалансир")" )

    link_auto_xhttp="vless://${BASE_BRIDGE_UUID}@$DOMAIN:443?security=tls&alpn=h2&type=xhttp&mode=stream-up&path=%2F$path_xhttp&extra=%7B%22noGRPCHeader%22%3Afalse%2C%22xPaddingBytes%22%3A%22150-400%22%2C%22scMaxEachPostBytes%22%3A3000000%2C%22scMinPostsIntervalMs%22%3A0%2C%22scMaxBufferedPosts%22%3A50%2C%22scStreamUpServerSecs%22%3A%2290-180%22%2C%22xmux%22%3A%7B%22maxConcurrency%22%3A%222-4%22%2C%22cMaxReuseTimes%22%3A%22800-1500%22%2C%22hMaxReusableSecs%22%3A%22900-1200%22%7D%7D&sni=$DOMAIN&fp=$fpBro#%F0%9F%87%B7%F0%9F%87%BA%20RU%3EEU%20%D0%90%D0%B2%D1%82%D0%BE%D0%B1%D0%B0%D0%BB%D0%B0%D0%BD%D1%81%D0%B8%D1%80"

    CONFIGS_ARRAY+=( "🇷🇺 RU>EU Автобалансир|$link_auto_xhttp" )
fi

# ================= 2. ПРОФИЛИ КОНКРЕТНЫХ НОД =================
for (( i=0; i<COUNT; i++ )); do
    REMARK_BASE="${NODE_NAME[$i]}"
    if [ -z "$REMARK_BASE" ]; then REMARK_BASE="Node_$i"; fi

    OUT_TLS_XHTTP=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "$DOMAIN",
          "port": 443,
          "users":[{ "id": "${BRIDGE_UUID[$i]}", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "alpn": [ "h2" ],
          "fingerprint": "$fpBro"
        },
        "xhttpSettings": {
          "mode": "stream-up",
          "path": "/$path_xhttp",
          "extra": {
            "noGRPCHeader": false,
            "xPaddingBytes": "150-400",
            "scMaxEachPostBytes": 3000000,
            "scMinPostsIntervalMs": 0,
            "scMaxBufferedPosts": 50,
            "scStreamUpServerSecs": "90-180",
            "xmux": {
              "maxConcurrency": "2-4",
              "cMaxReuseTimes": "800-1500",
              "hMaxReusableSecs": "900-1200"
            }
          }
        }
      }
    }
EOF
)

    OUT_TLS_VISION=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "$DOMAIN",
          "port": 443,
          "users":[{ "id": "${BRIDGE_UUID[$i]}", "flow": "xtls-rprx-vision", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "raw",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "fingerprint": "$fpBro"
        }
      }
    }
EOF
)

    EXTRA_VAL="${NODE_EXTRA[$i]}"
    if [ -z "$EXTRA_VAL" ]; then EXTRA_VAL="null"; fi

    OUT_DIRECT_EU=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "${NODE_ADDR[$i]}",
          "port": ${NODE_PORT[$i]},
          "users":[{ "id": "${NODE_UUID[$i]}", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "${NODE_TYPE[$i]}",
        "xhttpSettings": {
          "extra": $EXTRA_VAL,
          "mode": "${NODE_MODE[$i]}",
          "path": "${NODE_PATH[$i]}"
        },
        "security": "tls",
        "tlsSettings": {
          "serverName": "${NODE_SNI[$i]}",
          "fingerprint": "${NODE_FP[$i]}",
          "alpn": [ "h2", "http/1.1" ]
        }
      }
    }
EOF
)

    CLIENT_JSON_PROFILES+=( "$(print_config "$OUT_TLS_XHTTP" "🇷🇺 RU>EU xhttp | $REMARK_BASE")" )
    CLIENT_JSON_PROFILES+=( "$(print_config "$OUT_TLS_VISION" "🇷🇺 RU>EU raw | $REMARK_BASE")" )
    CLIENT_JSON_PROFILES+=( "$(print_config "$OUT_DIRECT_EU" "🇪🇺 EU dir | $REMARK_BASE")" )

    link_xhttp="vless://${BRIDGE_UUID[$i]}@$DOMAIN:443?security=tls&alpn=h2&type=xhttp&mode=stream-up&path=%2F$path_xhttp&extra=%7B%22noGRPCHeader%22%3Afalse%2C%22xPaddingBytes%22%3A%22150-400%22%2C%22scMaxEachPostBytes%22%3A3000000%2C%22scMinPostsIntervalMs%22%3A0%2C%22scMaxBufferedPosts%22%3A50%2C%22scStreamUpServerSecs%22%3A%2290-180%22%2C%22xmux%22%3A%7B%22maxConcurrency%22%3A%222-4%22%2C%22cMaxReuseTimes%22%3A%22800-1500%22%2C%22hMaxReusableSecs%22%3A%22900-1200%22%7D%7D&sni=$DOMAIN&fp=$fpBro#RU%3EEU_xhttp_$REMARK_BASE"
    link_raw="vless://${BRIDGE_UUID[$i]}@$DOMAIN:443?security=tls&type=tcp&headerType=&path=&host=&flow=xtls-rprx-vision&sni=$DOMAIN&fp=$fpBro&spx=%2F#RU%3EEU_raw_$REMARK_BASE"

    CONFIGS_ARRAY+=( "XHTTP TLS stream-up (RU>EU $REMARK_BASE)|$link_xhttp" )
    CONFIGS_ARRAY+=( "RAW VISION (RU>EU $REMARK_BASE)|$link_raw" )
    CONFIGS_ARRAY+=( "Direct EU ($REMARK_BASE)|${VLESS_URLS[$i]}" )
done

# Корректное объединение JSON массива профилей
( IFS=$','; echo "[${CLIENT_JSON_PROFILES[*]}]" ) > "$WEB_PATH/$path_subpage.json"

systemctl restart xray

subPageLink="https://$DOMAIN/$path_subpage.json"
configListLink="https://$DOMAIN/$path_subpage.html"

if [ "$INSTALL_MTP" = true ]; then
    echo -e "\n\n${GRN}Устанавливаем Telegram Web Proxy ${NC}"
    source <(curl -sL https://raw.githubusercontent.com/xVRVx/autoXRAY/refs/heads/main/test/telegram/web-proxy.sh)
else
    MTProto=""
fi

cat > "$WEB_PATH/$path_subpage.html" <<'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta name="robots" content="noindex,nofollow">
<title>autoXRAY bridge configs</title>
<link rel="icon" type="image/svg+xml" href='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDBCRkZGIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTIxIDJsLTIgMm0tNy42MSA3LjYxYTUuNSA1LjUgMCAxIDEtNy43NzggNy43NzggNS41IDUuNSAwIDAgMSA3Ljc3Ny03Ljc3N3ptMCAwTDE1LjUgNy41bTAgMGwzIDNMMjIgN2wtMy0zbS0zLjUgMy41TDE5IDQiLz48L3N2Zz4='>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcode/1.5.1/qrcode.min.js"></script>
<style>
body{font-family:monospace;background:#121212;color:#e0e0e0;padding:10px;max-width:900px;margin:0 auto}h2{color:#c3e88d;border-top:2px solid #333;padding-top:20px;margin:15px 0 10px;font-size:18px}.config-row{background:#1e1e1e;border:1px solid #333;border-radius:6px;padding:5px;display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:8px}.config-label{background:#2c2c2c;color:#82aaff;padding:6px 10px;border-radius:4px;font-weight:700;font-size:13px;white-space:nowrap;min-width:140px;text-align:center}.config-code{flex:1;white-space:nowrap;overflow-x:auto;padding:8px;background:#121212;border-radius:4px;color:#c3e88d;font-size:12px;scrollbar-width:none}.config-code::-webkit-scrollbar{display:none}.btn-action{border:1px solid #555;padding:6px 12px;border-radius:4px;cursor:pointer;font-weight:700;font-size:12px;transition:all .2s;height:32px;display:flex;align-items:center;justify-content:center}.copy-btn{background:#333;color:#e0e0e0;min-width:60px}.copy-btn:hover{background:#c3e88d;color:#121212;border-color:#c3e88d}.qr-btn{background:#333;color:#82aaff;border-color:#82aaff;min-width:40px}.qr-btn:hover{background:#82aaff;color:#121212}.btn-group{display:flex;gap:10px;margin:10px 0 20px}.btn{flex:1;background:#2c2c2c;color:#c3e88d;border:1px solid #c3e88d;padding:10px;text-align:center;border-radius:6px;text-decoration:none;font-weight:700;font-size:14px}.btn:hover{background:#c3e88d;color:#121212}.btn.download{border-color:#82aaff;color:#82aaff}.btn.download:hover{background:#82aaff;color:#121212}.btn.tg{border-color:#2AABEE;color:#2AABEE}.btn.tg:hover{background:#2AABEE;color:#fff}.modal-overlay{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.85);z-index:999;justify-content:center;align-items:center;backdrop-filter:blur(3px)}.modal-content{background:#1e1e1e;padding:20px;border-radius:10px;border:1px solid #82aaff;text-align:center}#qrcode{background:#fff;padding:10px;border-radius:6px;margin-bottom:10px}#qrcode canvas,#qrcode img{display:block;margin:0 auto}.qr-err{color:#c31e1e;font-size:13px;padding:10px;background:#fff;border-radius:4px;font-weight:700}.close-modal-btn{background:#c31e1e;color:#fff;border:none;padding:8px 20px;border-radius:4px;cursor:pointer}@media(max-width:600px){.config-label{width:100%;margin-bottom:2px}.config-code{min-width:100%;order:3}.btn-action{flex:1;order:2}}
</style>
<script>
function copyText(e,t){navigator.clipboard.writeText(document.getElementById(e).innerText.trim()).then(()=>{let o=t.innerText;t.innerText="OK",t.style.cssText="background:#c3e88d;color:#121212",setTimeout(()=>{t.innerText=o,t.style.cssText=""},1500)}).catch(e=>console.error(e))}
function showQR(e){
    let t=document.getElementById(e).innerText.trim(),o=document.getElementById("qrModal"),n=document.getElementById("qrcode");
    n.innerHTML="";
    if(e==='cAll'||t.length>1800){
        n.innerHTML="<div class='qr-err'>❌ Слишком много данных для одного QR-кода.<br>Используйте кнопку Copy.</div>";
        o.style.display="flex";
        return;
    }
    let c=document.createElement("canvas");
    n.appendChild(c);
    QRCode.toCanvas(c,t,{width:256,margin:2,errorCorrectionLevel:'L'},function(err){
        if(err){
            console.error(err);
            n.innerHTML="<div class='qr-err'>❌ Ошибка создания QR.<br>Скопируйте ссылку вручную.</div>";
        }
    });
    o.style.display="flex";
}
function closeModal(){document.getElementById("qrModal").style.display="none"}
window.onclick=function(e){e.target==document.getElementById("qrModal")&&closeModal()};
</script>
</head><body>
EOF

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

if [ "$INSTALL_MTP" = true ]; then
cat >> "$WEB_PATH/$path_subpage.html" <<EOF
<div class="config-row">
    <div class="config-label">Telegram Web Proxy</div>
    <div class="config-code" id="mtproto">${MTProto}</div>
    <button class="btn-action copy-btn" onclick="copyText('mtproto', this)">Copy</button>
    <a href="${MTProto}" target="_blank" class="btn-action qr-btn" title="автодобавление прокси в тг" style="text-decoration:none">✈️ Add to TG</a>
</div>
EOF
fi

cat >> "$WEB_PATH/$path_subpage.html" <<EOF
<h2>💠 Все конфиги вместе</h2>
<div class="config-row">
    <div class="config-code" id="cAll" style="max-height:60px;white-space:pre-wrap;word-break:break-all">$ALL_LINKS_TEXT</div>
    <button class="btn-action copy-btn" onclick="copyText('cAll', this)">Copy ALL</button>
</div>

<div><a style="color:white;margin:40px auto 20px;display:block;text-align:center;" href="https://github.com/xVRVx/autoXRAY">https://github.com/xVRVx/autoXRAY</a></div>

<div id="qrModal" class="modal-overlay"><div class="modal-content"><div id="qrcode"></div><button class="close-modal-btn" onclick="closeModal()">Close</button></div></div>
</body></html>
EOF

echo -e "\n${YEL}=== Финальная проверка статусов ===${NC}"
if [ "$INSTALL_MTP" = true ]; then
    if systemctl is-active --quiet telemt; then echo -e "Telemt: ${GRN}RUNNING${NC}"; else echo -e "Telemt: ${RED}STOPPED/ERROR${NC}"; fi
    if systemctl is-active --quiet tproxy-server; then echo -e "WebProxy: ${GRN}RUNNING${NC}"; else echo -e "WebProxy: ${RED}STOPPED/ERROR${NC}"; fi
fi
if systemctl is-active --quiet nginx; then echo -e "Nginx: ${GRN}RUNNING${NC}" ; else echo -e "Nginx: ${RED}STOPPED/ERROR${NC}"; fi
if systemctl is-active --quiet xray; then echo -e "XRAY: ${GRN}RUNNING${NC}"; else echo -e "XRAY: ${RED}STOPPED/ERROR${NC}"; fi

echo -e "\n"
if [ "$INSTALL_MTP" = true ]; then
    echo -e "${YEL}Telegram Web Proxy для ТГ:${NC}"
    echo -e "${CYAN}$MTProto${NC}\n"
fi

echo -e "
${YEL}✅ Сгенерировано мостов: ${GRN}$COUNT${NC}

${YEL}Ваша json страничка подписки: ${NC}
${GRN}$subPageLink${NC}

${YEL}Ссылка на сохраненные конфиги (Web UI): ${NC}
${GRN}$configListLink ${NC}

${GRN}Поддержать автора: https://github.com/xVRVx/autoXRAY ${NC}
"