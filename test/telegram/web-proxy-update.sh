#!/bin/bash
set -e

GRN='\033[1;32m'
YEL='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ Запустите скрипт с правами root${NC}"; exit 1; }

echo -e "${GRN}=== Обновление TeleMT и Telegram Web Proxy ===${NC}\n"

# --- 1. ОБНОВЛЕНИЕ TELEMT ---
echo -e "${GRN}[1/2] Обновление TeleMT...${NC}"
systemctl stop telemt 2>/dev/null || true

ARCH_TYPE=$(uname -m)
LIBC_TYPE=$(ldd --version 2>&1 | grep -iq musl && echo musl || echo gnu)
TMP_DIR=$(mktemp -d)

echo "Скачивание актуального релиза TeleMT..."
wget -qO- "https://github.com/telemt/telemt/releases/latest/download/telemt-${ARCH_TYPE}-linux-${LIBC_TYPE}.tar.gz" | tar -xz -C "$TMP_DIR"

# Кладем в правильный путь /usr/local/bin
mv "$TMP_DIR/telemt" /usr/local/bin/telemt
chmod +x /usr/local/bin/telemt
rm -rf "$TMP_DIR"

systemctl start telemt
echo -e "${YEL}TeleMT обновлен и запущен.${NC}\n"


# --- 2. ОБНОВЛЕНИЕ TPROXY-SERVER ---
echo -e "${GRN}[2/2] Обновление tproxy-server...${NC}"
systemctl stop tproxy-server 2>/dev/null || true

# Подготовка компилятора Go
GO_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
GO_BIN=""

if command -v go &>/dev/null && [ "$(go version | grep -oE 'go1\.[0-9]+' | cut -d. -f2)" -ge 20 ]; then
    GO_BIN=$(command -v go)
else
    echo "Загрузка временного Go..."
    mkdir -p /opt/go
    curl -sL "https://go.dev/dl/go1.22.6.linux-${GO_ARCH}.tar.gz" | tar -C /opt/go --strip-components=1 -xz
    GO_BIN="/opt/go/bin/go"
fi

# Скачивание исходников напрямую архивом (без git)
TMP_SRC=$(mktemp -d)
echo "Скачивание исходников tproxy-server..."
curl -sL "https://github.com/telegramdesktop/tproxy-server/archive/refs/heads/master.tar.gz" | tar -xz -C "$TMP_SRC" --strip-components=1

echo "Компиляция бинарника..."
cd "$TMP_SRC"
CGO_ENABLED=0 "$GO_BIN" build -trimpath -ldflags="-s -w" -o /usr/local/bin/tproxy-server ./cmd/tproxy-server
chmod +x /usr/local/bin/tproxy-server

# Очистка временных файлов
cd /root
rm -rf "$TMP_SRC" /opt/go

systemctl start tproxy-server
echo -e "${YEL}tproxy-server успешно пересобран и запущен.${NC}\n"


# --- 3. ПРОВЕРКА СТАТУСА ---
echo -e "${GRN}=== Проверка статуса сервисов ===${NC}"
sleep 1

telemt_status=$(systemctl is-active telemt || true)
tproxy_status=$(systemctl is-active tproxy-server || true)

if [ "$telemt_status" = "active" ]; then
    echo -e "TeleMT:        [ ${GRN}ACTIVE / RUNNING${NC} ]"
else
    echo -e "TeleMT:        [ ${RED}FAILED${NC} ]"
fi

if [ "$tproxy_status" = "active" ]; then
    echo -e "tproxy-server: [ ${GRN}ACTIVE / RUNNING${NC} ]"
else
    echo -e "tproxy-server: [ ${RED}FAILED${NC} ]"
fi

echo -e "\n${GRN}Готово! Все настройки, секреты и файлы сохранены.${NC}"