#!/bin/bash
set -e

echo "1. Остановка служб..."
systemctl stop tproxy-server telemt 2>/dev/null || true
systemctl disable tproxy-server telemt 2>/dev/null || true

echo "2. Удаление служб systemd..."
rm -f /etc/systemd/system/tproxy-server.service
rm -f /etc/systemd/system/telemt.service
systemctl daemon-reload
systemctl reset-failed

# 3. Удаление бинарников
echo "3. Удаление бинарных файлов..."
rm -f /usr/local/bin/tproxy-server
rm -f /bin/telemt

echo "4. Удаление конфигураций..."
rm -rf /etc/tproxy-server
rm -rf /etc/telemt
rm -rf /opt/telemt
rm -rf /opt/go
rm -rf /tmp/tproxy-source
rm -rf /srv/tproxy-site

echo "5. Удаление пользователя telemt..."
userdel telemt 2>/dev/null || true
groupdel telemt 2>/dev/null || true