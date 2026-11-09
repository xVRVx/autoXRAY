#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${GRN}Версия: 04-caddyBridge ${NC}"
sleep 1

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ Скрипту нужны root права!${NC}"; exit 1; }

. /etc/os-release 2>/dev/null
[[ "$ID" =~ ^(debian|ubuntu)$ ]] || { echo -e "${RED}❌ Ошибка: поддерживаются только Debian и Ubuntu!${NC}"; exit 1; }

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}❌ Ошибка: не переданы аргументы.${NC}"
    echo -e "${YEL}Использование:${NC} $0 <домен_моста> \"vless://...\" [\"vless://...\"]"
    exit 1
fi

DOMAIN=$1
shift
VLESS_URLS=("$@")
COUNT=${#VLESS_URLS[@]}

urldecode() {
    printf '%b' "${1//%/\\x}"
}

urlencode() {
    jq -rn --arg x "$1" '$x|@uri'
}

# 16 вариантов реалистичных ответов enterprise-авторизации
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

# Оптимизация сети (BBR + буферы)
cat <<EOF > /etc/sysctl.d/99-caddy-bridge.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_mtu_probing=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF
sysctl --system >/dev/null 2>&1

# Остановка конфликтующих веб-серверов перед установкой
for srv in nginx apache2; do
    if systemctl is-active --quiet $srv 2>/dev/null; then
        echo -e "${YEL}Останавливаем и отключаем $srv...${NC}"
        systemctl stop $srv 2>/dev/null
        systemctl disable $srv 2>/dev/null
    fi
done

# Установка Caddy и системных зависимостей (включая qrencode для консоли)
echo -e "${YEL}Установка Caddy и утилит...${NC}"
apt-get update && apt-get install -y debian-keyring debian-archive-keyring apt-transport-https \
    curl gnupg2 jq dnsutils openssl socat cron psmisc qrencode

curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

apt-get update
apt-get install -y caddy
systemctl enable --now cron

# Проверка IP и A-записи
LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]' | head -n 1)

if [ -n "$DNS_IP" ] && [ "$LOCAL_IP" != "$DNS_IP" ]; then
    echo -e "${RED}⚠️ Внимание: IP сервера ($LOCAL_IP) не совпадает с DNS A-записью $DOMAIN ($DNS_IP).${NC}"
    read -p "Продолжить выпуск сертификата? (y/N): " choice
    [[ "$choice" =~ ^[Yy]$ ]] || exit 1
fi

WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"
# Удаляем любые старые HTML-файлы ради безопасности
rm -f "$WEB_PATH"/*.html 2>/dev/null

echo -e "${YEL}Подготовка сайта маскировки...${NC}"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xVRVx/autoXRAY/main/test/gen_page3.sh)" -- "$WEB_PATH" 2>/dev/null || {
    cat <<EOF > "$WEB_PATH/index.html"
<!DOCTYPE html><html><head><title>Under Construction</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;">
<h1>Service is temporarily under maintenance</h1>
<p>Please check back later.</p></body></html>
EOF
}

# Удаление старых файлов подписок и генерация нового уникального пути
rm -f "$WEB_PATH"/*.json 2>/dev/null
path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

print_client_config() {
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
        "domain": [ "geosite:category-ads" ],
        "outboundTag": "block"
      },
      {
        "protocol": [ "bittorrent" ],
        "outboundTag": "direct"
      },
      {
        "domain": [ "domain:habr.com", "domain:apkmirror.com" ],
        "outboundTag": "proxy"
      },
      {
        "domain": [
          "geosite:private",
          "domain:ifconfig.me",
          "domain:checkip.amazonaws.com",
          "domain:ipify.org",
          "domain:2ip.io",
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
      "settings": { "udp": true },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls", "quic" ]
      }
    },
    {
      "tag": "socks-sb",
      "protocol": "mixed",
      "listen": "127.0.0.1",
      "port": 2080,
      "settings": { "udp": true },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls", "quic" ]
      }
    },
    {
      "tag": "http-in",
      "protocol": "http",
      "listen": "127.0.0.1",
      "port": 10809,
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls", "quic" ]
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
declare -A SEEN_PATHS
CADDY_HANDLERS=""

for (( i=0; i<COUNT; i++ )); do
    url="${VLESS_URLS[$i]}"
    [[ "$url" == vless://* ]] || { echo -e "${RED}❌ Неверный формат: $url${NC}"; exit 1; }

    url_body="${url#vless://}"
    if [[ "$url_body" == *"#"* ]]; then
        node_name="$(urldecode "${url_body##*#}")"
        url_body="${url_body%%#*}"
    else
        node_name="Node_$((i + 1))"
    fi

    node_uuid="${url_body%@*}"
    host_port_query="${url_body#*@}"
    node_addr="${host_port_query%%:*}"
    rest="${host_port_query#*:}"
    node_port="${rest%%\?*}"
    query_string="${rest#*\?}"

    unset params
    declare -A params
    IFS='&' read -ra pairs <<< "$query_string"
    for pair in "${pairs[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        params["$key"]="$(urldecode "$value")"
    done

    node_path="${params[path]:-/}"
    node_sni="${params[sni]:-$node_addr}"
    node_mode="${params[mode]:-stream-up}"
    node_fp="${params[fp]:-firefox}"
    node_extra="${params[extra]}"

    [[ "$node_path" == /* ]] || node_path="/$node_path"

    bridge_path="$node_path"
    strip_prefix_directive=""

    if [ $COUNT -gt 1 ]; then
        if [ -n "${SEEN_PATHS[$node_path]}" ] || [ "$node_path" == "/" ]; then
            bridge_path="/n$((i + 1))${node_path%/}"
            strip_prefix_directive="        uri strip_prefix /n$((i + 1))"
        fi
        SEEN_PATHS["$node_path"]=1
    fi

    CADDY_HANDLERS+=$(cat <<EOF

    handle ${bridge_path}* {
$strip_prefix_directive
        reverse_proxy https://${node_addr}:${node_port} {
            header_up Host ${node_sni}
            transport http {
                tls
                tls_server_name ${node_sni}
            }
            flush_interval -1
        }
    }
EOF
)

    if [ -n "$node_extra" ]; then
        json_extra="$node_extra"
    else
        json_extra='{
          "noGRPCHeader": true,
          "xPaddingBytes": "150-400",
          "scMaxEachPostBytes": 500000,
          "scMinPostsIntervalMs": "5-15",
          "scMaxBufferedPosts": 20,
          "scStreamUpServerSecs": "90-180",
          "xmux": {
            "maxConcurrency": "2-4",
            "cMaxReuseTimes": "800-1500",
            "hMaxReusableSecs": "900-1200"
          }
        }'
    fi

    OUT_TLS_XHTTP=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "$DOMAIN",
          "port": 443,
          "users":[{ "id": "${node_uuid}", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "alpn": [ "h2" ],
          "fingerprint": "$node_fp"
        },
        "xhttpSettings": {
          "mode": "${node_mode}",
          "path": "${bridge_path}",
          "extra": $json_extra
        }
      }
    }
EOF
)

    OUT_DIRECT_EU=$(cat <<EOF
    {
      "mux": { "concurrency": -1, "enabled": false },
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext":[{
          "address": "${node_addr}",
          "port": ${node_port},
          "users":[{ "id": "${node_uuid}", "encryption": "none" }]
        }]
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "${node_sni}",
          "alpn": [ "h2" ],
          "fingerprint": "$node_fp"
        },
        "xhttpSettings": {
          "mode": "${node_mode}",
          "path": "${node_path}",
          "extra": $json_extra
        }
      }
    }
EOF
)

    CLIENT_JSON_PROFILES+=( "$(print_client_config "$OUT_TLS_XHTTP" "🇷🇺 RU>EU xhttp | $node_name")" )
    CLIENT_JSON_PROFILES+=( "$(print_client_config "$OUT_DIRECT_EU" "🇪🇺 EU dir | $node_name")" )

    client_extra_enc=""
    if [ -n "$node_extra" ]; then
        client_extra_enc="&extra=$(urlencode "$node_extra")"
    fi

    path_enc=$(urlencode "$bridge_path")
    bridge_remark=$(urlencode "RU>EU_xhttp_$node_name")

    link_xhttp="vless://${node_uuid}@${DOMAIN}:443?security=tls&alpn=h2&type=xhttp&mode=${node_mode}&path=${path_enc}${client_extra_enc}&sni=${DOMAIN}&fp=${node_fp}#${bridge_remark}"
    
    CONFIGS_ARRAY+=( "XHTTP TLS stream-up (RU>EU $node_name)|$link_xhttp" )
    CONFIGS_ARRAY+=( "Direct EU ($node_name)|${VLESS_URLS[$i]}" )
done

# Сохранение клиентского JSON файла подписки
( IFS=$','; echo "[${CLIENT_JSON_PROFILES[*]}]" ) > "$WEB_PATH/${path_subpage}.json"

# Генерация Caddyfile c log { output discard }
CADDYFILE="/etc/caddy/Caddyfile"
cat <<EOF > "$CADDYFILE"
http://$DOMAIN {
    redir https://{host} permanent
}

$DOMAIN:443 {
    log {
        output discard
    }

    root * $WEB_PATH

    @authPost {
        path /api/v1/authenticate*
        method POST
    }
    handle @authPost {
        header {
            Content-Type "application/json"
            Set-Cookie "X-Auth-Token={http.request.uuid}; Path=/; HttpOnly; Secure; SameSite=Lax"
            X-Content-Type-Options "nosniff"
            Cache-Control "no-store, no-cache, must-revalidate"
        }
        respond \`{"success":false,"code":"$AUTH_CODE","message":"$AUTH_MSG","request_id":"{http.request.uuid}"}\` 401
    }

    @authOther path /api/v1/authenticate*
    handle @authOther {
        respond 403
    }

    @happJson path /${path_subpage}.json
    handle @happJson {
        header {
            profile-title "base64:YXV0b1hSQVk="
            routing "happ://routing/onadd/eyJOYW1lIjoiYXV0b1hSQVkiLCJHbG9iYWxQcm94eSI6InRydWUiLCJSb3V0ZU9yZGVyIjoiYmxvY2stcHJveHktZGlyZWN0IiwiUmVtb3RlRE5TVHlwZSI6IkRvSCIsIlJlbW90ZUROU0RvbWFpbiI6Imh0dHBzOi8vZG5zLmdvb2dsZS9kbnMtcXVlcnkiLCJSZW1vdGVETlNJUCI6IjguOC40LjQiLCJEb21lc3RpY0ROU1R5cGUiOiJEb0giLCJEb21lc3RpY0ROU0RvbWFpbiI6Imh0dHBzOi8vY29tbW9uLmRvdC5kbnMueWFuZGV4Lm5ldC9kbnMtcXVlcnkiLCJEb21lc3RpY0ROU0lQIjoiNzcuODguOC44IiwiR2VvaXB1cmwiOiJodHRwczovL2Nkbi5qc2RlbGl2ci5uZXQvZ2gvTG95YWxzb2xkaWVyL3YycmF5LXJ1bGVzLWRhdEByZWxlYXNlL2dlb2lwLmRhdCIsIkdlb3NpdGV1cmwiOiJodHRwczovL2Nkbi5qc2RlbGl2ci5uZXQvZ2gvTG95YWxzb2xkaWVyL3YycmF5LXJ1bGVzLWRhdEByZWxlYXNlL2dlb3NpdGUuZGF0IiwiTGFzdFVwZGF0ZWQiOiIxNzc1MjA2MTA4IiwiRG5zSG9zdHMiOnt9LCJEaXJlY3RTaXRlcyI6WyJnZW9zaXRlOmNhdGVnb3J5LXJ1IiwiZ2Vvc2l0ZTpwcml2YXRlIl0sIkRpcmVjdElwIjpbImdlb2lwOnByaXZhdGUiLCJnZW9pcDpydSJdLCJQcm94eVNpdGVzIjpbXSwiUHJveHlJcCI6W10sIkJsb2NrU2l0ZXMiOlsiZ2Vvc2l0ZTpjYXRlZ29yeS1hZHMiXSwiQmxvY2tJcCI6W10sIkRvbWFpblN0cmF0ZWd5IjoiSVBJZk5vbk1hdGNoIiwiRmFrZUROUyI6ImZhbHNlIiwiVXNlQ2h1bmtGaWxlcyI6ImZhbHNlIn0"
            socks-auth-mode "auto"
            http-auth-mode "auto"
            routing-enable "0"
            Content-Type "application/json; charset=utf-8"
            defer
        }
        file_server
    }
$CADDY_HANDLERS

    handle {
        file_server
    }
}
EOF

echo -e "${YEL}Валидация конфигурации Caddy...${NC}"
caddy validate --config "$CADDYFILE" || { echo -e "${RED}❌ Ошибка в Caddyfile!${NC}"; exit 1; }

systemctl restart caddy
systemctl enable caddy

echo -e "${YEL}⏳ Ожидание выпуска TLS-сертификата от Caddy...${NC}"

CERT_READY=false
for i in {1..20}; do
    if curl -sSI --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN" >/dev/null 2>&1; then
        CERT_READY=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$CERT_READY" = true ]; then
    echo -e "${GRN}✅ Сертификат успешно получен и проверен!${NC}"
else
    echo -e "${RED}❌ Не удалось получить сертификат вовремя!${NC}"
    echo -e "${YEL}Лог Caddy по выпуску сертификата:${NC}"
    journalctl -u caddy --no-pager -n 25 | grep -iE 'tls|certificate|error|acme'
    exit 1
fi

subPageLink="https://$DOMAIN/${path_subpage}.json"

sleep 1
systemctl is-active --quiet caddy && CADDY_STATUS="${GRN}RUNNING${NC}" || CADDY_STATUS="${RED}FAILED${NC}"

echo -e "\n=============================================="
echo -e "Статус Caddy: $CADDY_STATUS \n"

echo -e "\n${CYAN}--- Прямые ссылки конфигураций (скопируйте при необходимости) ---${NC}"
for item in "${CONFIGS_ARRAY[@]}"; do
    title="${item%%|*}"
    link="${item#*|}"
    echo -e "${YEL}$title${NC}"
    echo -e "$link\n"
done

echo -e "${YEL}QR-код подписки${NC}"
qrencode -t ANSIUTF8 "$subPageLink"

echo -e "\nСсылка на подписку (сохраните): ${GRN}$subPageLink${NC}\n"

history -c 2>/dev/null || true
[ -f ~/.bash_history ] && > ~/.bash_history
[ -f ~/.zsh_history ] && > ~/.zsh_history
unset HISTFILE