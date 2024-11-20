#!/bin/bash

# Получаем имя текущего пользователя
USER_NAME=$(whoami)

# Проверка, если пользователь существует
if ! id "$USER_NAME" &>/dev/null; then
    echo "Пользователь $USER_NAME не найден! Завершаю выполнение скрипта."
    exit 1
fi

# Создаем systemd сервис для автоматической авторизации на tty1
SERVICE_PATH="/etc/systemd/system/autologin@tty1.service"

echo "Создание сервиса для автоматической авторизации на tty1 для пользователя $USER_NAME..."

cat <<EOL > $SERVICE_PATH
[Unit]
Description=Autologin for tty1
After=systemd-user-sessions.service

[Service]
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I 38400 linux
Type=idle

[Install]
WantedBy=multi-user.target
EOL

# Даем права на создание/редактирование файла
chmod 644 $SERVICE_PATH

# Включаем сервис для автозапуска
echo "Включение сервиса для автоматической авторизации..."
systemctl enable autologin@tty1.service

# Перезагружаем систему
echo "Скрипт выполнен успешно. Перезагрузка системы..."
reboot

