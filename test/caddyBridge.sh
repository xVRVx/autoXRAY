#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${GRN}Версия: 02-caddyBridge ${NC}"
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

# Остановка конфликтующих веб-серверов
for srv in nginx apache2; do
    if systemctl is-active --quiet $srv; then
        echo -e "${YEL}Останавливаем и отключаем $srv (порты 80/443 нужны Caddy)...${NC}"
        systemctl stop $srv
        systemctl disable $srv
    fi
done

# Установка Caddy из официального репозитория
echo -e "${YEL}Установка Caddy и системных пакетов...${NC}"
apt-get update && apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg2 jq dnsutils

curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

apt-get update
apt-get install -y caddy

# Проверка DNS
LOCAL_IP=$(hostname -I | awk '{print $1}')
DNS_IP=$(dig +short "$DOMAIN" | grep '^[0-9]' | head -n 1)

if [ -n "$DNS_IP" ] && [ "$LOCAL_IP" != "$DNS_IP" ]; then
    echo -e "${RED}⚠️ Внимание: IP сервера ($LOCAL_IP) не совпадает с DNS A-записью $DOMAIN ($DNS_IP).${NC}"
    read -p "Продолжить выпуск сертификата? (y/N): " choice
    [[ "$choice" =~ ^[Yy]$ ]] || exit 1
fi

# Генерация сайта-маскировки
WEB_PATH="/var/www/$DOMAIN"
mkdir -p "$WEB_PATH"
echo -e "${YEL}Развертывание сайта маскировки...${NC}"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xVRVx/autoXRAY/main/test/gen_page3.sh)" -- "$WEB_PATH" 2>/dev/null || {
    cat <<EOF > "$WEB_PATH/index.html"
<!DOCTYPE html><html><head><title>Under Construction</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;">
<h1>Service is temporarily under maintenance</h1>
<p>Please check back later.</p></body></html>
EOF
}

declare -a CLIENT_LINKS
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

    # Если ссылок несколько и пути дублируются — изолируем префиксом
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

    client_extra_enc=""
    if [ -n "$node_extra" ]; then
        client_extra_enc="&extra=$(urlencode "$node_extra")"
    fi

    path_enc=$(urlencode "$bridge_path")
    bridge_remark=$(urlencode "RU-Bridge | $node_name")

    client_link="vless://${node_uuid}@${DOMAIN}:443?security=tls&alpn=h2&type=xhttp&mode=${node_mode}&path=${path_enc}${client_extra_enc}&sni=${DOMAIN}&fp=${node_fp}#${bridge_remark}"
    CLIENT_LINKS+=( "$node_name|$client_link" )
done

# Генерация Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
cat <<EOF > "$CADDYFILE"
$DOMAIN:443 {
    tls admin@$DOMAIN

    route /api/v1/authenticate {
        @notPost not method POST
        respond @notPost 403

        header {
            Content-Type application/json
            Set-Cookie "X-Auth-Token={http.request.uuid}; Path=/; HttpOnly; Secure; SameSite=Lax"
            X-Content-Type-Options nosniff
            Cache-Control "no-store, no-cache, must-revalidate"
        }
        respond \`{"success":false,"code":"ERR_INVALID_CREDENTIALS","message":"The identity or security key you provided is invalid.","request_id":"{http.request.uuid}"}\` 401
    }
$CADDY_HANDLERS

    handle {
        root * $WEB_PATH
        file_server
    }
}
EOF

echo -e "${YEL}Валидация конфигурации Caddy...${NC}"
caddy validate --config "$CADDYFILE" || { echo -e "${RED}❌ Ошибка в Caddyfile!${NC}"; exit 1; }

systemctl restart caddy
systemctl enable caddy

# Генерация страницы со ссылками
path_subpage=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)
PAGE_HTML="$WEB_PATH/${path_subpage}.html"

cat <<'EOF' > "$PAGE_HTML"
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Bridge Configs</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcode/1.5.1/qrcode.min.js"></script>
<style>
body{font-family:monospace;background:#121212;color:#e0e0e0;padding:15px;max-width:900px;margin:0 auto}
h2{color:#c3e88d;margin:20px 0 10px}
.row{background:#1e1e1e;border:1px solid #333;border-radius:6px;padding:8px;display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:10px}
.label{background:#2c2c2c;color:#82aaff;padding:6px 10px;border-radius:4px;font-weight:700;font-size:13px}
.code{flex:1;white-space:nowrap;overflow-x:auto;padding:8px;background:#121212;border-radius:4px;color:#c3e88d;font-size:12px}
.btn{background:#333;color:#e0e0e0;border:1px solid #555;padding:6px 12px;border-radius:4px;cursor:pointer;font-weight:700}
.btn:hover{background:#c3e88d;color:#121212}
.modal{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.85);justify-content:center;align-items:center}
.modal-content{background:#1e1e1e;padding:20px;border-radius:10px;border:1px solid #82aaff;text-align:center}
#qrcode{background:#fff;padding:10px;border-radius:6px;margin-bottom:10px}
</style>
<script>
function copy(id,btn){navigator.clipboard.writeText(document.getElementById(id).innerText.trim()).then(()=>{let o=btn.innerText;btn.innerText="OK";setTimeout(()=>btn.innerText=o,1200)})}
function qr(id){let t=document.getElementById(id).innerText.trim(),n=document.getElementById('qrcode');n.innerHTML="";let c=document.createElement("canvas");n.appendChild(c);QRCode.toCanvas(c,t,{width:256,margin:2});document.getElementById('modal').style.display='flex'}
function closeM(){document.getElementById('modal').style.display='none'}
</script>
</head><body>
<h2>🛡️ Caddy Bridge Конфиги</h2>
EOF

idx=1
for item in "${CLIENT_LINKS[@]}"; do
    name="${item%%|*}"
    link="${item#*|}"
    cat <<EOF >> "$PAGE_HTML"
<div class="row">
    <div class="label">$name</div>
    <div class="code" id="c$idx">$link</div>
    <button class="btn" onclick="copy('c$idx',this)">Copy</button>
    <button class="btn" onclick="qr('c$idx')">QR</button>
</div>
EOF
    ((idx++))
done

cat <<'EOF' >> "$PAGE_HTML"
<div id="modal" class="modal" onclick="closeM()"><div class="modal-content" onclick="event.stopPropagation()"><div id="qrcode"></div><button class="btn" onclick="closeM()">Закрыть</button></div></div>
</body></html>
EOF

sleep 2
systemctl is-active --quiet caddy && CADDY_STATUS="${GRN}RUNNING${NC}" || CADDY_STATUS="${RED}FAILED${NC}"

echo -e "\n=============================================="
echo -e "Статус Caddy: $CADDY_STATUS"
echo -e "Сайт-маскировка: ${CYAN}https://$DOMAIN/${NC}"
echo -e "Фейковый Auth API: ${CYAN}https://$DOMAIN/api/v1/authenticate${NC}"
echo -e "Веб-страница с конфигами и QR: ${GRN}https://$DOMAIN/${path_subpage}.html${NC}"
echo -e "==============================================\n"

echo -e "${YEL}Сгенерированные VLESS ссылки:${NC}"
for item in "${CLIENT_LINKS[@]}"; do
    name="${item%%|*}"
    link="${item#*|}"
    echo -e "\n${CYAN}[$name]${NC}\n$link"
done