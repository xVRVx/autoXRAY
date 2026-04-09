#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GRN}Версия: 121 ${NC}"

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ скрипту нужны root права ${NC}"; exit 1; }

DOMAIN=$1
shift # Сдвигаем аргументы, теперь все оставшиеся аргументы ($@) — это vless ссылки
VLESS_URLS=("$@")

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Ошибка: домен не задан.${NC}"
    exit 1
fi

if [ ${#VLESS_URLS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Ошибка: конфиги vless не заданы. Укажите хотя бы одну vless:// ссылку.${NC}"
    exit 1
fi

# Функция URL-декодинга
urldecode() {
    printf '%b' "${1//%/\\x}"
}

COUNT=${#VLESS_URLS[@]}
echo -e "${GRN}Обнаружено $COUNT vless ссылок для моста!${NC}"

# Массивы для хранения параметров каждой ноды
declare -a NODE_UUID NODE_ADDR NODE_PORT NODE_NAME NODE_TYPE NODE_SEC NODE_FP NODE_SNI NODE_PBK NODE_SID NODE_SPX NODE_MODE NODE_PATH NODE_EXTRA
# Уникальные UUID для сервера-моста (RU)
declare -a BRIDGE_UUID

# Генерируем базовый UUID сервера для всех подключений (будет один клиент в конфиге сервера)
SERVER_UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
# Разбиваем UUID на группы для удобной подмены 3-й группы (7 и 8 байты)
g1="${SERVER_UUID:0:8}"
g2="${SERVER_UUID:9:4}"
g3="${SERVER_UUID:14:4}"
g4="${SERVER_UUID:19:4}"
g5="${SERVER_UUID:24:12}"

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

    # Очищаем массив params
    unset params
    declare -A params
    IFS='&' read -ra pairs <<< "$query_string"
    for pair in "${pairs[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        params["$key"]="$(urldecode "$value")"
    done

    NODE_SEC[$i]="${params[security]}"
    NODE_TYPE[$i]="${params[type]}"
    NODE_PATH[$i]="${params[path]}"
    NODE_MODE[$i]="${params[mode]}"
    NODE_EXTRA[$i]="${params[extra]}"
    NODE_SNI[$i]="${params[sni]}"
    NODE_FP[$i]="${params[fp]}"
    NODE_PBK[$i]="${params[pbk]}"
    NODE_SID[$i]="${params[sid]}"
    NODE_SPX[$i]="${params[spx]}"

    # Встраиваем Vless Route ID (начиная с 1) в 3-ю группу UUID (7 и 8 байты) для клиента
    ROUTE_ID=$((i + 1))
    HEX_ROUTE_ID=$(printf "%04x" $ROUTE_ID)
    BRIDGE_UUID[$i]="${g1}-${g2}-${HEX_ROUTE_ID}-${g4}-${g5}"
done

# Порт прослушивания сервера-моста (единый для Inbound, обычно 443 для Reality)
SERVER_PORT=443

echo -e "${YEL}Обновление и установка необходимых пакетов...${NC}"
apt-get update && apt-get install curl jq dnsutils openssl nginx certbot wget tar -y
systemctl enable --now nginx

LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]' | head -n 1)

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
bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [ "$bbr" = "bbr" ]; then
    echo -e "${GRN}BBR уже запущен${NC}"
else
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/999-autoXRAY.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/999-autoXRAY.conf
    sysctl --system
    echo -e "${GRN}BBR активирован${NC}"
fi

cat <<EOF > /etc/security/limits.d/99-autoXRAY.conf
*       soft    nofile  1048576
*       hard    nofile  1048576
root    soft    nofile  1048576
root    hard    nofile  1048576
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

path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

# конфиг nginx
cat <<EOF > "$CONFIG_PATH"
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

    location = /${path_subpage}.json {
		add_header profile-title "base64:YXV0b1hSQVk=";
		add_header routing "happ://routing/onadd/eyJOYW1lIjoiYXV0b1hSQVkiLCJHbG9iYWxQcm94eSI6InRydWUiLCJSb3V0ZU9yZGVyIjoiYmxvY2stcHJveHktZGlyZWN0IiwiUmVtb3RlRE5TVHlwZSI6IkRvSCIsIlJlbW90ZUROU0RvbWFpbiI6Imh0dHBzOi8vZG5zLmdvb2dsZS9kbnMtcXVlcnkiLCJSZW1vdGVETlNJUCI6IjguOC40LjQiLCJEb21lc3RpY0ROU1R5cGUiOiJEb0giLCJEb21lc3RpY0ROU0RvbWFpbiI6Imh0dHBzOi8vY2xvdWRmbGFyZS1kbnMuY29tL2Rucy1xdWVyeSIsIkRvbWVzdGljRE5TSVAiOiIxLjEuMS4xIiwiR2VvaXB1cmwiOiJodHRwczovL2dpdGh1Yi5jb20vTG95YWxzb2xkaWVyL3YycmF5LXJ1bGVzLWRhdC9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvZ2VvaXAuZGF0IiwiR2Vvc2l0ZXVybCI6Imh0dHBzOi8vZ2l0aHViLmNvbS9Mb3lhbHNvbGRpZXIvdjJyYXktcnVsZXMtZGF0L3JlbGVhc2VzL2xhdGVzdC9kb3dubG9hZC9nZW9zaXRlLmRhdCIsIkxhc3RVcGRhdGVkIjoiMTc3NTIwNjEwOCIsIkRuc0hvc3RzIjp7fSwiRGlyZWN0U2l0ZXMiOlsiZ2Vvc2l0ZTpjYXRlZ29yeS1ydSIsImdlb3NpdGU6cHJpdmF0ZSJdLCJEaXJlY3RJcCI6WyJnZW9pcDpwcml2YXRlIl0sIlByb3h5U2l0ZXMiOltdLCJQcm94eUlwIjpbXSwiQmxvY2tTaXRlcyI6WyJnZW9zaXRlOmNhdGVnb3J5LWFkcyIsImdlb3NpdGU6d2luLXNweSJdLCJCbG9ja0lwIjpbXSwiRG9tYWluU3RyYXRlZ3kiOiJJUElmTm9uTWF0Y2giLCJGYWtlRE5TIjoiZmFsc2UiLCJVc2VDaHVua0ZpbGVzIjoiZmFsc2UifQ";
		
		add_header routing-enable 0;
	}

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

# Создание директории
WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"

# Генерируем сайт маскировку
bash -c "$(curl -sL https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/gen_page2.sh)" -- "$WEB_PATH"

# Установка Xray
bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

SCRIPT_DIR=/usr/local/etc/xray

# Генерируем глобальные ключи для сервера-моста
key_output=$(xray x25519)
xray_privateKey_vrv=$(echo "$key_output" | awk -F': ' '/PrivateKey/ {print $2}')
xray_publicKey_vrv=$(echo "$key_output" | awk -F': ' '/Password/ {print $2}')
xray_shortIds_vrv=$(openssl rand -hex 8)

path_xhttp=$(openssl rand -base64 15 | tr -dc 'a-z0-9' | head -c 6)

socksUser=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 6)
socksPasw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)

# ====СОЗДАНИЕ КОНФИГА СЕРВЕРА В ЦИКЛЕ ====

ROUTING_RULES=""
OUTBOUNDS=""

for (( i=0; i<COUNT; i++ )); do
    ROUTE_ID=$((i + 1))

    # Наполняем правила маршрутизации с использованием vlessRoute (проверка 7 и 8 байта UUID)
    ROUTING_RULES+="$(cat <<EOF
      { "vlessRoute": "$ROUTE_ID", "outboundTag": "proxy-$i" },
EOF
)"

    # Если параметр extra пустой, подставляем null
    EXTRA_VAL="${NODE_EXTRA[$i]}"
    if [ -z "$EXTRA_VAL" ]; then EXTRA_VAL="null"; fi

    # Наполняем outbounds (к конечным EU нодам) — используем ИХ родные порты
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
        "security": "${NODE_SEC[$i]}",
        "realitySettings": {
          "show": false,
          "fingerprint": "${NODE_FP[$i]}",
          "serverName": "${NODE_SNI[$i]}",
          "password": "${NODE_PBK[$i]}",
          "shortId": "${NODE_SID[$i]}",
          "mldsa65Verify": "",
          "spiderX": "${NODE_SPX[$i]}"
        }
      }
    },
EOF
)"
done

# Удаляем запятую в конце
ROUTING_RULES="${ROUTING_RULES%,}"


# Создаем JSON конфигурацию сервера
cat << EOF > "$SCRIPT_DIR/config.json"
{
  "log": {
    "dnsLog": false,
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "none"
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
      "port": 500,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "flow": "xtls-rprx-vision",
            "id": "$SERVER_UUID"
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
            "$xray_shortIds_vrv"
          ],
          "privateKey": "$xray_privateKey_vrv",
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
            "id": "$SERVER_UUID"
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
          "mode": "stream-one",
          "path": "/$path_xhttp",
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
        "balancerTag": "Super_Balancer"
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
          "RUsocks5"
        ],
        "balancerTag": "Super_Balancer"
      },
$ROUTING_RULES
    ]
  }
}
EOF

# Создаем JSON конфигурацию клиента
print_config() {
  local PROXY_OUTBOUND="$1"
  local REMARK="$2"

  cat << TPL
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "servers":[
      "https://8.8.4.4/dns-query",
      "https://8.8.8.8/dns-query",
      "https://1.1.1.1/dns-query"
    ],
    "queryStrategy": "UseIPv4"
  },
  "routing": {
    "domainMatcher": "hybrid",
    "domainStrategy": "IPIfNonMatch",
    "rules":[
      {
        "domain":[
          "geosite:category-ads",
          "geosite:win-spy"
        ],
        "outboundTag": "block"
      },
      {
        "protocol":[
          "bittorrent"
        ],
        "outboundTag": "direct"
      },
      {
        "domain":[
          "habr.com", "apkmirror.com"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain":[
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
        "ip":[
          "geoip:private"
        ],
        "outboundTag": "direct"
      }
    ]
  },
  "inbounds":[
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
        "destOverride":[ "http", "tls", "quic" ]
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
        "destOverride":[ "http", "tls", "quic" ]
      }
    },
    {
      "tag": "http-in",
      "protocol": "http",
      "listen": "127.0.0.1",
      "port": 10809,
      "sniffing": {
        "enabled": true,
        "destOverride":[ "http", "tls", "quic" ]
      }
    }
  ],
  "outbounds":[
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

CLIENT_CONFIGS=""
declare -a CONFIGS_ARRAY
ALL_LINKS_TEXT=""

# Цикл генерации клиентов по каждой ссылке
for (( i=0; i<COUNT; i++ )); do
    REMARK_BASE="${NODE_NAME[$i]}"
    if [ -z "$REMARK_BASE" ]; then REMARK_BASE="Node_$i"; fi

    # --- Config: Bridge XHTTP (идет на мост, порт $SERVER_PORT) ---
    OUT_REALITY_XHTTP=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "$DOMAIN",
          "port": $SERVER_PORT,
          "users":[{ "id": "${BRIDGE_UUID[$i]}", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "xhttpSettings": {
          "mode": "stream-one",
          "path": "/$path_xhttp",
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
          "password": "$xray_publicKey_vrv", "shortId": "$xray_shortIds_vrv", "spiderX": "/"
        }
      }
    }
EOF
)

    # --- Config: Bridge RAW Vision (идет на мост, порт $SERVER_PORT) ---
    OUT_REALITY_VISION=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "$DOMAIN",
          "port": $SERVER_PORT,
          "users":[{ "id": "${BRIDGE_UUID[$i]}", "flow": "xtls-rprx-vision", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false, "fingerprint": "chrome", "serverName": "$DOMAIN",
          "password": "$xray_publicKey_vrv", "shortId": "$xray_shortIds_vrv", "spiderX": "/"
        }
      }
    }
EOF
)

    EXTRA_VAL="${NODE_EXTRA[$i]}"
    if [ -z "$EXTRA_VAL" ]; then EXTRA_VAL="null"; fi

    # --- Config: Direct EU (идет напрямую на целевую ноду, её родной порт) ---
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
        "security": "${NODE_SEC[$i]}",
        "realitySettings": {
          "show": false,
          "fingerprint": "${NODE_FP[$i]}",
          "serverName": "${NODE_SNI[$i]}",
          "password": "${NODE_PBK[$i]}",
          "shortId": "${NODE_SID[$i]}",
          "mldsa65Verify": "",
          "spiderX": "${NODE_SPX[$i]}"
        }
      }
    }
EOF
)

    # Генерируем 3 конфига на ноду и склеиваем в массив JSON
    CLIENT_CONFIGS+="$(print_config "$OUT_REALITY_XHTTP" "🇷🇺 RU>EU xhttp | $REMARK_BASE")"
    CLIENT_CONFIGS+=","
    CLIENT_CONFIGS+="$(print_config "$OUT_REALITY_VISION" "🇷🇺 RU>EU raw | $REMARK_BASE")"
    CLIENT_CONFIGS+=","
    CLIENT_CONFIGS+="$(print_config "$OUT_DIRECT_EU" "🇪🇺 EU dir | $REMARK_BASE")"

    if [ $i -lt $((COUNT-1)) ]; then
        CLIENT_CONFIGS+=","
    fi

    # --- Генерируем ссылки vless:// для HTML странички (с портом моста) ---
    link_xhttp="vless://${BRIDGE_UUID[$i]}@$DOMAIN:$SERVER_PORT?security=reality&type=xhttp&headerType=&path=%2F$path_xhttp&host=&mode=stream-one&extra=%7B%22xmux%22%3A%7B%22cMaxReuseTimes%22%3A%221000-3000%22%2C%22maxConcurrency%22%3A%223-5%22%2C%22maxConnections%22%3A0%2C%22hKeepAlivePeriod%22%3A0%2C%22hMaxRequestTimes%22%3A%22400-700%22%2C%22hMaxReusableSecs%22%3A%221200-1800%22%7D%2C%22headers%22%3A%7B%7D%2C%22noGRPCHeader%22%3Afalse%2C%22xPaddingBytes%22%3A%22400-800%22%2C%22scMaxEachPostBytes%22%3A1500000%2C%22scMinPostsIntervalMs%22%3A20%2C%22scStreamUpServerSecs%22%3A%2260-240%22%7D&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#RU%3EEU_xhttp_$REMARK_BASE"

    link_raw="vless://${BRIDGE_UUID[$i]}@$DOMAIN:$SERVER_PORT?security=reality&type=tcp&headerType=&path=&host=&flow=xtls-rprx-vision&sni=$DOMAIN&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&spx=%2F#RU%3EEU_raw_$REMARK_BASE"

    CONFIGS_ARRAY+=( "XHTTP (RU>EU $REMARK_BASE)|$link_xhttp" )
    CONFIGS_ARRAY+=( "RAW VISION (RU>EU $REMARK_BASE)|$link_raw" )
    CONFIGS_ARRAY+=( "Direct EU ($REMARK_BASE)|${VLESS_URLS[$i]}" )
done

# Записываем массив в файл подписки
echo "[$CLIENT_CONFIGS]" > "$WEB_PATH/$path_subpage.json"

systemctl restart xray
echo -e "Перезапуск XRAY"

subPageLink="https://$DOMAIN/$path_subpage.json"
configListLink="https://$DOMAIN/$path_subpage.html"

echo -e "\n\n${GRN}Устанавливаем MTProto FakeTLS ${NC}"
source <(curl -sL https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/telemt-test.sh)

echo -e "\n\n${GRN}Создаем страницу подписки ${NC}"
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

<h2>➡️ Конфиги ($COUNT VPS x 3 протокола)</h2>
EOF

# Вывод строк конфигов
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

SOCKS5_url="tg://socks?server=$DOMAIN&port=10443&user=${socksUser}&pass=${socksPasw}"

# Дописываем Socks5, MTProto, All links и подвал
cat >> "$WEB_PATH/$path_subpage.html" <<EOF
<div class="config-row">
    <div class="config-label">Мост Socks5 (TG)</div>
    <div class="config-code" id="sock">${SOCKS5_url}</div>
    <button class="btn-action copy-btn" onclick="copyText('sock', this)">Copy</button>
    <a href="${SOCKS5_url}" target="_blank" class="btn-action qr-btn" title="автодобавление моста в тг" style="text-decoration:none">✈️ Add to TG</a>
</div>

<div class="config-row">
    <div class="config-label">Мост MTProtoFakeTLS (TG)</div>
    <div class="config-code" id="mtproto">${MTProto}</div>
    <button class="btn-action copy-btn" onclick="copyText('mtproto', this)">Copy</button>
    <a href="${MTProto}" target="_blank" class="btn-action qr-btn" title="автодобавление моста в тг" style="text-decoration:none">✈️ Add to TG</a>
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

if systemctl is-active --quiet telemt; then echo -e "Telemt: ${GRN}RUNNING${NC}"; else echo -e "Telemt: ${RED}STOPPED/ERROR${NC}"; fi
if systemctl is-active --quiet nginx; then echo -e "Nginx: ${GRN}RUNNING${NC}"; else echo -e "Nginx: ${RED}STOPPED/ERROR${NC}"; fi
if systemctl is-active --quiet xray; then echo -e "XRAY: ${GRN}RUNNING${NC}"; else echo -e "XRAY: ${RED}STOPPED/ERROR${NC}"; fi

echo -e "
${YEL}✅ Сгенерировано мостов: ${GRN}$COUNT${NC}

${YEL}Ваша json страничка подписки ${NC}
${GRN}$subPageLink${NC}

${YEL}Ссылка на сохраненные конфиги (Web UI) ${NC}
${GRN}$configListLink ${NC}

${YEL}MTProto FakeTLS для ТГ${NC}
${GRN}$MTProto ${NC}

Скопируйте подписку в специализированное приложение:
- iOS: Happ или v2RayTun или v2rayN
- Android: Happ или v2RayTun или v2rayNG
- Windows: конфиги Happ или winLoadXRAY или v2rayN
	для vless v2RayTun или Throne

Открыт локальный socks5 на порту 10443.
Внутри клиента: socks5 на 10808, 2080 и http на 10809.

${GRN}Поддержать автора: https://github.com/xVRVx/autoXRAY ${NC}

"