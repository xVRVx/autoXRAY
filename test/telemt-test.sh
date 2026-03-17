echo -e "${GRN}Версия телемт: 111 ${NC}"

wget -qO- "https://github.com/telemt/telemt/releases/latest/download/telemt-$(uname -m)-linux-$(ldd --version 2>&1 | grep -iq musl && echo musl || echo gnu).tar.gz" | tar -xz
mv telemt /bin
chmod +x /bin/telemt

telemtHEX16=$(openssl rand -hex 16)

mkdir -p /etc/telemt

cat <<EOF > "/etc/telemt/telemt.toml"
[general]
prefer_ipv6 = false
fast_mode = true
use_middle_proxy = false

[general.modes]
classic = false
secure = false
tls = true

[server]
port = 443
listen_addr_ipv4 = "0.0.0.0"

# === Timeouts (in seconds) ===
[timeouts]
client_handshake = 15
tg_connect = 10
client_keepalive = 60
client_ack = 300

[server.api]
enabled = true
listen = "127.0.0.1:9091"
# whitelist = ["127.0.0.1/32"]
# read_only = true

# === Anti-Censorship & Masking ===
[censorship]
tls_domain = "$DOMAIN"
mask = true
mask_port = 500
mask_host = "127.0.0.1"
fake_cert_len = 2048

[access.users]
hello = "$telemtHEX16"

[[upstreams]]
type = "socks5"
address = "127.0.0.1:10443" 
username = "$socksUser"
password = "$socksPasw"
weight = 10
enabled = true
EOF

useradd -d /opt/telemt -m -r -U telemt
chown -R telemt:telemt /etc/telemt

cat <<EOF > "/etc/systemd/system/telemt.service"
[Unit]
Description=Telemt
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=telemt
Group=telemt
WorkingDirectory=/opt/telemt
ExecStart=/bin/telemt /etc/telemt/telemt.toml
Restart=on-failure
LimitNOFILE=65536
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
sleep 1
systemctl start telemt
systemctl enable telemt

sleep 3
telemtSecret=$(curl -s http://127.0.0.1:9091/v1/users | jq -r '.data[0].links.tls[0] | split("secret=")[1]')

MTProto="https://t.me/proxy?server=$DOMAIN&port=443&secret=$telemtSecret"