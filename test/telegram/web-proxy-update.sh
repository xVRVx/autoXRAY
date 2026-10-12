#!/bin/bash
set -e

GRN='\033[1;32m'
YEL='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ Запустите скрипт с правами root${NC}"; exit 1; }

echo -e "${GRN}=== Обновление TeleMT и Telegram Web Proxy ===${NC}\n"

# Создаем временные каталоги с гарантированной очисткой при выходе
TMP_DIR=$(mktemp -d)
TMP_SRC=$(mktemp -d)
CLEAN_OPT_GO=false

cleanup() {
    rm -rf "$TMP_DIR" "$TMP_SRC" /tmp/go.tgz
    if [ "$CLEAN_OPT_GO" = true ]; then
        rm -rf /opt/go
    fi
}
trap cleanup EXIT

# --- 1. ОБНОВЛЕНИЕ TELEMT ---
echo -e "${GRN}[1/2] Обновление TeleMT...${NC}"
systemctl stop telemt 2>/dev/null || true

ARCH_TYPE=$(uname -m)
LIBC_TYPE=$(ldd --version 2>&1 | grep -iq musl && echo musl || echo gnu)

echo "Скачивание актуального релиза TeleMT..."
curl -fsSL --retry 2 "https://github.com/telemt/telemt/releases/latest/download/telemt-${ARCH_TYPE}-linux-${LIBC_TYPE}.tar.gz" \
    | tar -xz -C "$TMP_DIR" || { echo -e "${RED}❌ Ошибка скачивания TeleMT${NC}"; exit 1; }

[ -f "$TMP_DIR/telemt" ] || { echo -e "${RED}❌ Бинарник TeleMT не найден в архиве${NC}"; exit 1; }

mv -f "$TMP_DIR/telemt" /usr/local/bin/telemt
chmod +x /usr/local/bin/telemt

systemctl start telemt
echo -e "${YEL}TeleMT обновлен и запущен.${NC}\n"


# --- 2. ОБНОВЛЕНИЕ TPROXY-SERVER ---
echo -e "${GRN}[2/2] Обновление tproxy-server...${NC}"
systemctl stop tproxy-server 2>/dev/null || true

GO_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
GO_BIN=""

# Проверяем, есть ли уже подходящий системный Go (требуется >= 1.20)
if command -v go &>/dev/null; then
    SYS_GO_VER=$(go version 2>/dev/null | grep -oE 'go1\.[0-9]+' | cut -d. -f2 || true)
    if [ -n "$SYS_GO_VER" ] && [ "$SYS_GO_VER" -ge 20 ] 2>/dev/null; then
        GO_BIN=$(command -v go)
        echo "Используется системный Go: $(go version)"
    fi
fi

# Если системного нет или он старый — скачиваем Go 1.22.6 с зеркалом и валидацией хеша
if [ -z "$GO_BIN" ]; then
    echo "Загрузка Go 1.22.6..."
    GO_TGZ="go1.22.6.linux-${GO_ARCH}.tar.gz"

    case "$GO_ARCH" in
        amd64) GO_SHA256="999805bed7d9039ec3da1a53bfbcafc13e367da52aa823cb60b68ba22d44c616" ;;
        arm64) GO_SHA256="c15fa895341b8eaf7f219fada25c36a610eb042985dc1a912410c1c90098eaf2" ;;
        *) echo -e "${RED}❌ Неподдерживаемая архитектура: $GO_ARCH${NC}"; exit 1 ;;
    esac

    mkdir -p /opt/go
    CLEAN_OPT_GO=true

    for url in "https://go.dev/dl/$GO_TGZ" "https://mirrors.aliyun.com/golang/$GO_TGZ"; do
        if curl -fsSL --retry 2 "$url" -o /tmp/go.tgz && \
           echo "$GO_SHA256  /tmp/go.tgz" | sha256sum -c --quiet - && \
           tar -C /opt/go --strip-components=1 -xzf /tmp/go.tgz; then
            break
        fi
        echo -e "${YEL}Не удалось скачать Go с $url, пробую зеркало...${NC}"
    done
    rm -f /tmp/go.tgz

    [ -x /opt/go/bin/go ] || { echo -e "${RED}❌ Не удалось развернуть Go тулчейн${NC}"; exit 1; }
    GO_BIN="/opt/go/bin/go"
fi

# Скачивание свежих исходников tproxy-server
echo "Скачивание исходников tproxy-server..."
curl -fsSL --retry 2 "https://github.com/telegramdesktop/tproxy-server/archive/refs/heads/master.tar.gz" \
    | tar -xz -C "$TMP_SRC" --strip-components=1 || { echo -e "${RED}❌ Ошибка скачивания исходников tproxy-server${NC}"; exit 1; }

echo "Компиляция бинарника..."
cd "$TMP_SRC"
CGO_ENABLED=0 "$GO_BIN" build -trimpath -ldflags="-s -w" -o /usr/local/bin/tproxy-server ./cmd/tproxy-server \
    || { echo -e "${RED}❌ Ошибка сборки tproxy-server${NC}"; exit 1; }

chmod +x /usr/local/bin/tproxy-server
cd /root

systemctl start tproxy-server
echo -e "${YEL}tproxy-server успешно пересобран и запущен.${NC}\n"


# --- 3. ПРОВЕРКА СТАТУСА ---
echo -e "${GRN}=== Проверка статуса сервисов ===${NC}"
sleep 2

telemt_status=$(systemctl is-active telemt 2>/dev/null || true)
tproxy_status=$(systemctl is-active tproxy-server 2>/dev/null || true)

if [ "$telemt_status" = "active" ]; then
    echo -e "TeleMT:        [ ${GRN}ACTIVE / RUNNING${NC} ]"
else
    echo -e "TeleMT:        [ ${RED}FAILED${NC} ] (журнал: journalctl -u telemt -e)"
fi

if [ "$tproxy_status" = "active" ]; then
    echo -e "tproxy-server: [ ${GRN}ACTIVE / RUNNING${NC} ]"
else
    echo -e "tproxy-server: [ ${RED}FAILED${NC} ] (журнал: journalctl -u tproxy-server -e)"
fi

echo -e "\n${GRN}Готово! Все настройки, секреты и файлы сохранены.${NC}"