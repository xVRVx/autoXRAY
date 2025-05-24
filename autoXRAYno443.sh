#!/bin/bash

port1=${1:-4443}
port2=${2:-8443}
port3=${3:-2040}

echo "port1: $port1"
echo "port2: $port2"
echo "port3: $port3"

echo "Обновление и установка необходимых пакетов..."
apt update && apt install sudo -y
#sudo apt update && sudo apt upgrade -y
sudo apt update && sudo apt install -y jq

echo "Настройка DNS..."
echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null

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
xray_privateKey_vrv=$(echo "$key_output" | awk -F': ' '/Private key/ {print $2}')
xray_publicKey_vrv=$(echo "$key_output" | awk -F': ' '/Public key/ {print $2}')

xray_shortIds_vrv=$(openssl rand -hex 8)

xray_sspasw_vrv=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)

ipserv=$(hostname -I | awk '{print $1}')



# Экспортируем переменные для envsubst
export xray_uuid_vrv xray_dest_vrv xray_dest_vrv222 xray_privateKey_vrv xray_publicKey_vrv xray_shortIds_vrv xray_sspasw_vrv port1 port2 port3

# Создаем JSON конфигурацию на основе шаблона
#cat << 'EOF' | envsubst > output.json
# Создаем JSON конфигурацию на основе шаблона и сохраняем в папку скрипта
cat << 'EOF' | envsubst > "$SCRIPT_DIR/config.json"
{
    "dns": {
        "servers": [
            "https+local://8.8.4.4/dns-query",
            "https+local://8.8.8.8/dns-query",
            "localhost"
        ]
    },
    "log": {
        "loglevel": "none",
        "dnsLog": false
    },
    "routing": {
        "rules": [
            {
                "domain": [
                    "geosite:category-ads",
                    "geosite:win-spy"
                ],
                "outboundTag": "block"
            },
            {
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block",
                "type": "field"
            }
        ]
    },
  "inbounds": [
    {
      "tag": "VTR$port1",
      "listen": "0.0.0.0",
      "port": $port1,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "flow": "xtls-rprx-vision",
            "id": "${xray_uuid_vrv}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${xray_dest_vrv}:443",
          "xver": 0,
          "serverNames": [
            "${xray_dest_vrv}"
          ],
          "privateKey": "${xray_privateKey_vrv}",
          "publicKey": "${xray_publicKey_vrv}",
          "shortIds": [
            "${xray_shortIds_vrv}"
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
      "tag": "VTR$port2",
      "listen": "0.0.0.0",
      "port": $port2,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "flow": "xtls-rprx-vision",
            "id": "${xray_uuid_vrv}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${xray_dest_vrv222}:443",
          "xver": 0,
          "serverNames": [
            "${xray_dest_vrv222}"
          ],
          "privateKey": "${xray_privateKey_vrv}",
          "publicKey": "${xray_publicKey_vrv}",
          "shortIds": [
            "${xray_shortIds_vrv}"
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
      "tag": "SS$port3",
      "listen": "0.0.0.0",
      "port": $port3,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          {
            "password": "${xray_sspasw_vrv}",
            "method": "chacha20-ietf-poly1305"
          }
        ],
        "network": "tcp,udp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}

EOF

# Перезапуск Xray
echo "Перезапуск Xray..."
sudo systemctl restart xray

echo "Готово!
"

# Формирование ссылок для вывода
link1="vless://${xray_uuid_vrv}@${ipserv}:$port1?security=reality&sni=${xray_dest_vrv}&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#VPN-vless-$port1"

link2="vless://${xray_uuid_vrv}@${ipserv}:$port2?security=reality&sni=${xray_dest_vrv222}&fp=chrome&pbk=${xray_publicKey_vrv}&sid=${xray_shortIds_vrv}&type=tcp&flow=xtls-rprx-vision&encryption=none#VPN-vless-$port2"

ENCODED_STRING=$(echo -n "chacha20-ietf-poly1305:${xray_sspasw_vrv}" | base64)
link3="ss://$ENCODED_STRING@${ipserv}:$port3#VPN-ShadowS-$port3"
	
echo -e "

Ваши VPN конфиги. Первый - самый надежный, остальные резервные!

\033[32m$link1\033[0m
"
echo -e "\033[32m$link2\033[0m
"
echo -e "\033[32m$link3\033[0m

Скопируйте конфиг в специализированное приложение:
- iOS: Happ или v2rayTun или FoXray
- Android: Happ или v2rayTun или v2rayNG
- Windows: Hiddify или Nekoray

Сайт с инструкциями: blog.skybridge.run

Поддержать автора: https://github.com/xVRVx/autoXRAY

"