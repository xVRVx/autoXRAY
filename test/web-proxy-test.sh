# === Telegram Web Proxy (TeleMT Classic + tproxy-server) ===
echo -e "${GRN}Версия: 115 ${NC}"
sleep 1
echo -e "\n${GRN}=== Установка бэкенда TeleMT и Web Proxy шлюза ===${NC}"

# Останавливаем старые службы, если были
systemctl stop telemt tproxy-server 2>/dev/null || true

# Генерируем 16-байтный (32 hex) секрет для Web Proxy
SECRET=$(openssl rand -hex 16)

# 1. Установка TeleMT (бэкенд на 127.0.0.1:9000 в Classic MTProto режиме)
ARCH_TYPE=$(uname -m)
LIBC_TYPE=$(ldd --version 2>&1 | grep -iq musl && echo musl || echo gnu)

wget -qO- "https://github.com/telemt/telemt/releases/latest/download/telemt-${ARCH_TYPE}-linux-${LIBC_TYPE}.tar.gz" | tar -xz -C /tmp
mv /tmp/telemt /usr/local/bin/telemt
chmod +x /usr/local/bin/telemt

mkdir -p /etc/telemt /opt/telemt

cat <<EOF > "/etc/telemt/telemt.toml"
[general]
prefer_ipv6 = false
fast_mode = true
use_middle_proxy = false

[general.modes]
classic = true
secure = false
tls = false

[server]
port = 9000
listen_addr_ipv4 = "127.0.0.1"

[timeouts]
client_handshake = 15
client_keepalive = 60
client_ack = 300

[server.api]
enabled = true
listen = "127.0.0.1:9091"
whitelist = ["127.0.0.1/32"]

[access.users]
default = "$SECRET"

[[upstreams]]
type = "socks5"
address = "127.0.0.1:10443"
username = "$socksUser"
password = "$socksPasw"
weight = 10
enabled = true
EOF

id -u telemt &>/dev/null || useradd -d /opt/telemt -m -r -U telemt
chown -R telemt:telemt /etc/telemt /opt/telemt

cat <<EOF > "/etc/systemd/system/telemt.service"
[Unit]
Description=TeleMT Classic MTProto Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=telemt
Group=telemt
WorkingDirectory=/opt/telemt
ExecStart=/usr/local/bin/telemt /etc/telemt/telemt.toml
Restart=on-failure
RestartSec=3
LimitNOFILE=65536
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now telemt

# 2. Загрузка и сборка tproxy-server (без зависимости от git)
echo -e "${GRN}[2/4] Загрузка и сборка tproxy-server...${NC}"
GO_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
mkdir -p /opt/go
curl -sL "https://go.dev/dl/go1.22.6.linux-${GO_ARCH}.tar.gz" | tar -C /opt/go --strip-components=1 -xz

# Скачиваем архив исходников напрямую через curl
rm -rf /tmp/tproxy-source
mkdir -p /tmp/tproxy-source
curl -sL "https://github.com/telegramdesktop/tproxy-server/archive/refs/heads/master.tar.gz" | tar -xz -C /tmp/tproxy-source --strip-components=1

# Статическая сборка (CGO_ENABLED=0 не требует gcc/make)
cd /tmp/tproxy-source
CGO_ENABLED=0 /opt/go/bin/go build -trimpath -ldflags="-s -w" -o /usr/local/bin/tproxy-server ./cmd/tproxy-server
chmod +x /usr/local/bin/tproxy-server
rm -rf /tmp/tproxy-source /opt/go
cd /root

# 3. Конфигурация tproxy-server
mkdir -p /etc/tproxy-server

# Токен подписи (строго 32 байта)
if [ ! -s /etc/tproxy-server/token.key ] || [ "$(wc -c < /etc/tproxy-server/token.key)" -ne 32 ]; then
    head -c 32 /dev/urandom > /etc/tproxy-server/token.key
fi

# Гарантируем наличие каталога и index.html
mkdir -p "$WEB_PATH"
if [ ! -f "$WEB_PATH/index.html" ]; then
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>$DOMAIN</title></head><body><h1>Server Ready</h1></body></html>" > "$WEB_PATH/index.html"
fi
chmod 755 "$WEB_PATH"

cat <<EOF > /etc/tproxy-server/config.json
{
  "public_hostname": "$DOMAIN",
  "listen": "127.0.0.1:8080",
  "admin_listen": "127.0.0.1:8081",
  "public_dir": "$WEB_PATH",
  "profiles_file": "/etc/tproxy-server/profiles.json",
  "token_key_file": "/etc/tproxy-server/token.key",
  "enable_pprof": false,
  "limits": {
    "max_header_bytes": 16384,
    "max_body_bytes": 2097152,
    "max_frame_payload": 1048576,
    "carrier_batch_bytes": 2097152,
    "max_streams_per_session": 128,
    "max_closed_stream_ids": 4096,
    "max_pending_per_session": 33554432,
    "max_pending_global": 536870912,
    "max_pending_items_per_session": 16384,
    "max_pending_items_global": 262144,
    "max_sessions_per_ip": 0,
    "max_sessions_global": 256,
    "max_streams_global": 4096,
    "max_backend_dials_in_flight": 256,
    "new_sessions_per_minute": 600,
    "new_sessions_burst": 128,
    "new_streams_per_minute": 6000,
    "new_streams_burst": 512,
    "max_bootstraps_per_ip": 0,
    "max_bootstraps_global": 512,
    "new_bootstraps_per_minute": 1200,
    "new_bootstraps_burst": 256,
    "max_profiles": 32
  },
  "timeouts": {
    "backend_dial": "5s",
    "long_poll": "25s",
    "reconnect_grace": "2m",
    "bootstrap_lifetime": "2m",
    "read_header": "10s",
    "idle": "75s",
    "shutdown": "15s"
  }
}
EOF

# Порт бэкенда изменен на 9000
cat <<EOF > /etc/tproxy-server/profiles.json
{
  "profiles": [
    {
      "name": "default",
      "secret": "$SECRET",
      "backend": "127.0.0.1:9000"
    }
  ]
}
EOF

# Настройка прав
chmod 0400 /etc/tproxy-server/token.key
chmod 0600 /etc/tproxy-server/profiles.json
chown -R telemt:telemt /etc/tproxy-server

# Служба tproxy-server (Wants вместо Requires)
cat <<EOF > "/etc/systemd/system/tproxy-server.service"
[Unit]
Description=Telegram Web Proxy Relay
After=network.target telemt.service
Wants=telemt.service

[Service]
Type=simple
User=telemt
Group=telemt
ExecStart=/usr/local/bin/tproxy-server -config /etc/tproxy-server/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65536
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now tproxy-server

# 4. Экспорт переменной для родительского скрипта autoXRAY
export MTProto="tg://webproxy?server=${DOMAIN}&secret=${SECRET}"

sleep 2
if systemctl is-active --quiet telemt && systemctl is-active --quiet tproxy-server; then
    echo -e "${GRN}✅ TeleMT (9000) и tproxy-server (8080) успешно запущены! (${DOMAIN})${NC}"
else
    echo -e "${RED}⚠️ Ошибка запуска! Проверьте логи: journalctl -u telemt -u tproxy-server -e${NC}"
fi
sleep 1