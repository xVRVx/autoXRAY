#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

echo -e "${GRN}Версия: 132 ${NC}"
sleep 1

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ Скрипту нужны root права!${NC}"; exit 1; }

# Проверка, что система именно Debian
if [ ! -f /etc/debian_version ]; then
    echo -e "${RED}❌ Ошибка: этот скрипт предназначен только для Debian!${NC}"
    exit 1
fi

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Ошибка: домен не задан.${NC}"
    exit 1
fi

echo -e "${YEL}Подготовка официального репозитория Nginx для Debian...${NC}"
apt-get update && apt-get install -y curl gnupg2 ca-certificates lsb-release debian-archive-keyring jq dnsutils openssl wget tar socat cron

# Добавление ключа и репозитория nginx.org
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor --yes -o /usr/share/keyrings/nginx-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian $(lsb_release -cs) nginx" \
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
    echo -e "${YEL}Правильно укажите одну A-запись для вашего домена в ДНС - $LOCAL_IP ${NC}"
    
	read -p "Продолжить на ваш страх и риск? (y/N):" choice

	if [[ ! "$choice" =~ ^[Yy]$ ]]; then
		echo -e "${RED}Выполнение скрипта прервано.${NC}"
		exit 1
	fi
    echo -e "${YEL}Продолжение выполнения скрипта...${NC}"
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
# ============================

# Включаем BBR и MTU Probing
cat <<EOF > /etc/sysctl.d/999-autoXRAY.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_mtu_probing=1
EOF
sysctl --system >/dev/null 2>&1
echo -e "${GRN}BBR и TCP MTU Probing активированы${NC}"

cat <<EOF > /etc/security/limits.d/99-autoXRAY.conf
*       soft    nofile  1048576
*       hard    nofile  1048576
root    soft    nofile  1048576
root    hard    nofile  1048576
EOF
ulimit -n 65535
echo -e "${GRN}Лимиты применены. Текущий ulimit -n: $(ulimit -n) ${NC}"

# Создание директории сайта
WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"

# Генерируем сайт маскировку
bash -c "$(curl -sL https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/gen_page3.sh)" -- "$WEB_PATH"

# Установка Xray
bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v26.7.28

# ==========================================
# Блок ACME.SH (Установка и выпуск сертификата)
# ==========================================
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

echo -e "\n${YEL}Проверка и установка acme.sh...${NC}"
curl -sL https://get.acme.sh | sh -s email=mail@$DOMAIN
ACME_BIN="$HOME/.acme.sh/acme.sh"

# Проверяем, существует ли уже выпущенный сертификат для этого домена
CERT_EXISTS=false
if $ACME_BIN --list | grep -q "$DOMAIN"; then
    echo -e "${GRN}Сертификат для $DOMAIN уже существует в acme.sh.${NC}"
    CERT_EXISTS=true
fi

if [ "$CERT_EXISTS" = false ]; then
    # Регистрируем аккаунт в ZeroSSL напрямую через ACME
    $ACME_BIN --register-account -m mail@$DOMAIN --server zerossl

    echo -e "\n${YEL}Выпуск сертификата (сначала ZeroSSL, затем Let's Encrypt)...${NC}"
    $ACME_BIN --issue -d "$DOMAIN" -w /var/www/html --server zerossl --keylength ec-256
    RET=$?
    
    if [ $RET -ne 0 ]; then
        echo -e "${YEL}ZeroSSL не ответил, пробуем через Let's Encrypt...${NC}"
        $ACME_BIN --issue -d "$DOMAIN" -w /var/www/html --server letsencrypt --keylength ec-256
        RET=$?
    fi
else
    # Если сертификат уже был выпущен ранее, считаем статус успешным
    RET=0
fi

if [ $RET -eq 0 ]; then
    # Установка сертификата и настройка автообновления
    $ACME_BIN --install-cert -d "$DOMAIN" --ecc \
      --fullchain-file /var/lib/xray/cert/fullchain.pem \
      --key-file /var/lib/xray/cert/privkey.pem \
      --reloadcmd "chmod 744 /var/lib/xray/cert/privkey.pem /var/lib/xray/cert/fullchain.pem; systemctl reload nginx; systemctl restart xray"

    chmod 744 /var/lib/xray/cert/privkey.pem /var/lib/xray/cert/fullchain.pem

    echo -e "\n${GRN}========================================"
    echo    "✅  Сертификат успешно настроен и применен!"
    echo    "✅  acme.sh настроил автообновление через cron"
    echo    "========================================"
    echo -e "${NC}"
else
    echo -e "\n${RED}========================================"
    echo    "❌  ОШИБКА: не удалось выпустить сертификат через acme.sh"
    echo    "========================================"
    echo -e "${NC}"
    exit 1
fi
# ==========================================

path_xhttp=$(openssl rand -base64 15 | tr -dc 'a-z0-9' | head -c 6)
path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

AUTH_VARIANTS=(
    "ERR_INVALID_CREDENTIALS|The username or password you entered is incorrect."
    "ERR_INVALID_CREDENTIALS|The identity or security key you provided is invalid."
    "ERR_BAD_PASSWORD|Incorrect password. Please verify your credentials and retry."
    "ERR_KEY_MISMATCH|The security key provided does not match the account identity."
    "ERR_CREDENTIAL_REJECTED|Credential verification rejected by the authentication authority."
    "ERR_PASSWORD_MISMATCH|The password provided does not match the registered key."
    "ERR_INCORRECT_KEY|Incorrect security credentials provided for this principal."
    "ERR_USER_NOT_FOUND|Principal identity not found in directory services."
    "ERR_IDENTITY_NOT_FOUND|No account found matching the provided identity."
    "ERR_PRINCIPAL_MISSING|User principal does not exist in this organizational realm."
    "ERR_ACCOUNT_NOT_FOUND|Account identifier not recognized by the identity provider."
    "ERR_UNKNOWN_USER|Unrecognized user identity. Please verify your login."
    "ERR_LOOKUP_FAILED|User lookup failed: Specified identity does not exist."
    "ERR_AUTH_FAILED|Authentication failed: The provided credentials do not match."
    "ERR_DIRECTORY_MISMATCH|Credentials could not be verified against the corporate directory."
    "ERR_RECORDS_MISMATCH|The security credentials entered do not match our records."
)

RAND_AUTH=${AUTH_VARIANTS[$RANDOM % ${#AUTH_VARIANTS[@]}]}
AUTH_CODE=$(echo "$RAND_AUTH" | cut -d'|' -f1)
AUTH_MSG=$(echo "$RAND_AUTH" | cut -d'|' -f2)

# Конфиг Nginx
cat <<EOF > "$CONFIG_PATH"
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    server_name $DOMAIN;

    listen unix:/dev/shm/nginxTLS.sock proxy_protocol;
    listen unix:/dev/shm/nginx_h2.sock http2 proxy_protocol;

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
        add_header routing "happ://routing/onadd/eyJOYW1lIjoiYXV0b1hSQVkiLCJHbG9iYWxQcm94eSI6InRydWUiLCJSb3V0ZU9yZGVyIjoiYmxvY2stcHJveHktZGlyZWN0IiwiUmVtb3RlRE5TVHlwZSI6IkRvSCIsIlJlbW90ZUROU0RvbWFpbiI6Imh0dHBzOi8vZG5zLmdvb2dsZS9kbnMtcXVlcnkiLCJSZW1vdGVETlNJUCI6IjguOC40LjQiLCJEb21lc3RpY0ROU1R5cGUiOiJEb0giLCJEb21lc3RpY0ROU0RvbWFpbiI6Imh0dHBzOi8vY2xvdWRmbGFyZS1kbnMuY29tL2Rucy1xdWVyeSIsIkRvbWVzdGljRE5TSVAiOiIxLjEuMS4xIiwiR2VvaXB1cmwiOiJodHRwczovL2dpdGh1Yi5jb20vTG95YWxzb2xkaWVyL3YycmF5LXJ1bGVzLWRhdC9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvZ2VvaXAuZGF0IiwiR2Vvc2l0ZXVybCI6Imh0dHBzOi8vZ2l0aHViLmNvbS9Mb3lhbHNvbGRpZXIvdjJyYXktcnVsZXMtZGF0L3JlbGVhc2VzL2xhdGVzdC9kb3dubG9hZC9nZW9zaXRlLmRhdCIsIkxhc3RVcGRhdGVkIjoiMTc3NTIwNjEwOCIsIkRuc0hvc3RzIjp7fSwiRGlyZWN0U2l0ZXMiOlsiZ2Vvc2l0ZTpjYXRlZ29yeS1ydSIsImdlb3NpdGU6cHJpdmF0ZSJdLCJEaXJlY3RJcCI6WyJnZW9pcDpwcml2YXRlIl0sIlByb3h5U2l0ZXMiOltdLCJQcm94eUlwIjpbXSwiQmxvY2tTaXRlcyI6WyJnZW9pcDpjYXRlZ29yeS1hZHMiLCJnZW9zaXRlOndpbi1zcHkiXSwiQmxvY2tJcCI6W10sIkRvbWFpblN0cmF0ZWd5IjoiSVBJZk5vbk1hdGNoIiwiRmFrZUROUyI6ImZhbHNlIiwiVXNlQ2h1bmtGaWxlcyI6ImZhbHNlIn0";
        add_header routing-enable 0;
        try_files \$uri =404;
    }

    # XHTTP endpoint
    location /${path_xhttp} {
        proxy_pass http://127.0.0.1:8400;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;

        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Для сайта
    location /api/v1/authenticate {
        limit_except POST {
            deny all;
        }

        default_type application/json;

        add_header Set-Cookie "X-Auth-Token=\$request_id; Path=/; HttpOnly; Secure; SameSite=Lax" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate" always;

        return 401 '{"success":false,"code":"$AUTH_CODE","message":"$AUTH_MSG","request_id":"\$request_id"}';
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
echo -e "${GRN}✅ Конфигурация nginx обновлена.${NC}"

SCRIPT_DIR=/usr/local/etc/xray

# Генерируем ключи и переменные
xray_uuid_vrv=$(xray uuid)
xray_shortIds_vrv=$(openssl rand -hex 8)

socksUser=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 6)
socksPasw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 16)

# Экспортируем переменные для envsubst
export xray_uuid_vrv xray_shortIds_vrv DOMAIN path_subpage path_xhttp WEB_PATH socksUser socksPasw fpBro

# Создаем JSON конфигурацию сервера Xray (только Vision, Hy2, XHTTP, local SOCKS5)
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
      "tag": "vsRAWtlsVISION",
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
            "alpn": "h2",
            "dest": "/dev/shm/nginx_h2.sock",
            "xver": 2
          },
          {
            "dest": "/dev/shm/nginxTLS.sock",
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
          "alpn": [
            "h2", "http/1.1"
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
      "tag": "Hysteria2",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "hysteria",
      "settings": {
        "version": 2,
        "clients": [
          {
            "auth": "${xray_shortIds_vrv}"
          }
        ]
      },
      "streamSettings": {
        "network": "hysteria",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "alpn": [
            "h3"
          ],
          "certificates": [
            {
              "usage": "encipherment",
              "certificateFile": "/var/lib/xray/cert/fullchain.pem",
              "keyFile": "/var/lib/xray/cert/privkey.pem"
            }
          ]
        },
        "hysteriaSettings": {
          "version": 2
        },
        "finalmask": {
          "quicParams": {
            "congestion": "brutal",
            "brutalUp": "70 mbps",
            "brutalDown": "70 mbps"
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
      "tag": "socks5",
      "port": 10443,
      "listen": "127.0.0.1",
      "protocol": "mixed",
      "settings": {
        "ip": "127.0.0.1",
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
    "domainStrategy": "IPIfNonMatch",
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
        "outboundTag": "block",
        "domain": [
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
          "2ip.io",
          "geosite:category-ip-geo-detect"
        ]
      }
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
          "habr.com",
          "apkmirror.com"
        ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:private",
          "ifconfig.me",
          "checkip.amazonaws.com",
          "pify.org",
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
          "geoip:ru",
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

# --- Config 1: VLESS RAW TLS VISION (Port 443 TCP)
OUT_VISION='{
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
    "security": "tls",
    "tlsSettings": {
      "serverName": "$DOMAIN",
      "fingerprint": "$fpBro"
    }
  }
}'

# --- Config 2: HYSTERIA2 (Port 443 UDP)
HYSTERIA2='{
"tag": "proxy",
"protocol": "hysteria",
"settings": {
	"address": "$DOMAIN",
	"port": 443,
	"version": 2
},
"streamSettings": {
	"network": "hysteria",
	"security": "tls",
	"tlsSettings": {
		"serverName": "$DOMAIN",
		"alpn": [
			"h3"
		],
		"fingerprint": "$fpBro"
	},
	"hysteriaSettings": {
		"version": 2,
		"auth": "${xray_shortIds_vrv}"
	},
	"finalmask": {
		"quicParams": {
			"congestion": "brutal",
			"brutalUp": "70 mbps",
			"brutalDown": "70 mbps"
		}
	}
}
}'

# --- Config 3: VLESS XHTTP TLS (Port 443 TCP)
OUT_XHTTP='{
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
    "xhttpSettings": {
		"extra": {
			"headers": {},
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
		},
	"mode": "auto", "path": "/${path_xhttp}" },
    "security": "tls",
    "tlsSettings": { "serverName": "$DOMAIN", "fingerprint": "$fpBro" }
  }
}'

(
  echo "["
  print_config "$OUT_VISION"    "🇪🇺 VLESS RAW TLS VISION (443)"
  echo ","
  print_config "$HYSTERIA2"      "🇪🇺 HYSTERIA2 (UDP 443)"
  echo ","
  print_config "$OUT_XHTTP"     "🇪🇺 VLESS XHTTP TLS EXTRA (443)"
  echo "]"
) | envsubst > "$WEB_PATH/$path_subpage.json"

systemctl restart xray
echo -e "Перезапуск XRAY"

# Формирование ссылок
subPageLink="https://$DOMAIN/$path_subpage.json"

hy2="hy2://${xray_shortIds_vrv}@$DOMAIN:443/?sni=$DOMAIN&alpn=h3#Hysteria2"
linkTLS1="vless://${xray_uuid_vrv}@$DOMAIN:443?security=tls&type=tcp&headerType=&path=&host=&flow=xtls-rprx-vision&sni=$DOMAIN&fp=$fpBro&spx=%2F#vlessRAWtlsVision-autoXRAY"
linkTLS2="vless://${xray_uuid_vrv}@$DOMAIN:443?security=tls&type=xhttp&headerType=&path=%2F${path_xhttp}&host=&mode=auto&extra=%7B%22xmux%22%3A%7B%22cMaxReuseTimes%22%3A%221000-3000%22%2C%22maxConcurrency%22%3A%223-5%22%2C%22maxConnections%22%3A0%2C%22hKeepAlivePeriod%22%3A0%2C%22hMaxRequestTimes%22%3A%22400-700%22%2C%22hMaxReusableSecs%22%3A%221200-1800%22%7D%2C%22headers%22%3A%7B%7D%2C%22noGRPCHeader%22%3Afalse%2C%22xPaddingBytes%22%3A%22400-800%22%2C%22scMaxEachPostBytes%22%3A1500000%2C%22scMinPostsIntervalMs%22%3A20%2C%22scStreamUpServerSecs%22%3A%2260-240%22%7D&sni=$DOMAIN&fp=$fpBro&spx=%2F#vlessXHTTPtls-autoXRAY"

configListLink="https://$DOMAIN/$path_subpage.html"

CONFIGS_ARRAY=(
    "VLESS RAW TLS VISION|$linkTLS1"
    "HYSTERIA2|$hy2"
    "VLESS XHTTP TLS EXTRA|$linkTLS2"
)
ALL_LINKS_TEXT=""

if [ "$INSTALL_MTP" = true ]; then
    echo -e "\n\n${GRN}Устанавливаем Telegram Web Proxy ${NC}"
    source <(curl -sL https://github.com/xVRVx/autoXRAY/raw/refs/heads/main/test/web-proxy-test.sh)
else
    echo -e "\n\n${YEL}Установка Telegram Web Proxy пропущена.${NC}"
    MTProto=""
fi

# --- ЗАПИСЬ HEAD (СТАТИКА, МИНИФИЦИРОВАННЫЕ СТИЛИ И JS) ---
cat > "$WEB_PATH/$path_subpage.html" <<'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta name="robots" content="noindex,nofollow">
<title>autoXRAY configs</title>
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

# Добавляем Web Proxy блок (чистые tg:// ссылки)
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

# Дописываем конец страницы
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

# --- ФИНАЛЬНАЯ ПРОВЕРКА ---
echo -e "\n${YEL}=== Финальная проверка статусов ===${NC}"

if [ "$INSTALL_MTP" = true ]; then
    if systemctl is-active --quiet telemt; then echo -e "Telemt: ${GRN}RUNNING${NC}"; else echo -e "Telemt: ${RED}STOPPED/ERROR${NC}"; fi
    if systemctl is-active --quiet tproxy-server; then echo -e "WebProxy: ${GRN}RUNNING${NC}"; else echo -e "WebProxy: ${RED}STOPPED/ERROR${NC}"; fi
fi

if systemctl is-active --quiet nginx; then
    echo -e "Nginx: ${GRN}RUNNING${NC}"
else
    echo -e "Nginx: ${RED}STOPPED/ERROR${NC}"
fi

if systemctl is-active --quiet xray; then
    echo -e "XRAY: ${GRN}RUNNING${NC}"
else
    echo -e "XRAY: ${RED}STOPPED/ERROR${NC}"
fi

echo -e "\n"

if [ "$INSTALL_MTP" = true ]; then
    echo -e "${YEL}Telegram Web Proxy для ТГ:${NC}"
    echo -e "${CYAN}$MTProto${NC}\n"
fi

echo -e "${YEL}VLESS RAW TLS VISION (Порт 443 TCP) ${NC}
$linkTLS1

${YEL}HYSTERIA2 (Порт 443 UDP) ${NC}
$hy2

${YEL}VLESS XHTTP TLS EXTRA (Порт 443 TCP - для моста) ${NC}
$linkTLS2

${YEL}Ваша json страничка подписки ${NC}
$subPageLink

${YEL}Ссылка на сохраненные конфиги ${NC}
${GRN}$configListLink ${NC}

Скопируйте подписку в специализированное приложение:
- iOS: Happ или v2RayTun или v2rayN
- Android: Happ или v2RayTun или v2rayNG
- Windows: конфиги Happ или winLoadXRAY или v2rayN
	для vless v2RayTun или Throne

Внутри клиента открыт socks5 на 10808, 2080 и http на 10809.

${GRN}Поддержать автора: https://github.com/xVRVx/autoXRAY ${NC}
"