#!/bin/bash

# Цвета для вывода
GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YEL}Удаляем WARP-cli...${NC}"
echo -e "y" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) u

echo -e "${YEL}Начало установки Cloudflare WARP...${NC}"

apt-get update
apt-get install gpg curl sudo lsb-release iproute2 -y

curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

sudo apt-get update && sudo apt-get install cloudflare-warp -y

yes y | warp-cli registration new
warp-cli mode proxy
warp-cli connect

echo -e "${YEL}Ожидание запуска прокси (3 секунды)...${NC}"
sleep 3

# Проверка WARP-CF (Socks5 порт 40000)
if ss -nlt | grep -q ":40000\b"; then
    echo -e "WARP-cli: ${GRN}LISTENING${NC} (Port: 40000)"
else
    echo -e "WARP-cli: ${RED}NOT LISTENING${NC}"
    warp-cli status
fi