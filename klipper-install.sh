#!/bin/bash

# Проверка прав доступа (sudo)
if [ "$EUID" -ne 0 ]; then
    echo "Скрипт требует права суперпользователя. Запрашиваем пароль для повышения прав..."
    # Перезапускаем скрипт с sudo
    sudo "$0" "$@"
    exit
fi

# Функция для обработки ошибок
error_exit() {
    echo "Ошибка на шаге: $1"
    exit 1
}

# Функция паузы с таймером
pause() {
    echo "Переход к следующему этапу через 3 секунды..."
    sleep 3
}

echo "Обновление системы..."
pause
apt update && apt upgrade -y || error_exit "Обновление системы"

echo "Установка необходимых пакетов..."
pause
apt install -y git python3 python3-virtualenv python3-dev build-essential libffi-dev libncurses-dev \
               libusb-dev avrdude gcc-avr binutils-avr avr-libc stm32flash dfu-util unzip || error_exit "Установка пакетов"

echo "Клонирование репозитория Klipper..."
pause
cd ~
git clone https://github.com/Klipper3d/klipper.git || error_exit "Клонирование репозитория Klipper"

echo "Настройка виртуального окружения для Klipper..."
pause
cd ~/klipper
python3 -m venv .venv || error_exit "Создание виртуального окружения"
source .venv/bin/activate
pip install -r scripts/klippy-requirements.txt || error_exit "Установка зависимостей для Klipper"

echo "Компиляция прошивки для микроконтроллера..."
pause
make menuconfig || error_exit "Запуск menuconfig"
# Откройте меню настройки конфигурации, выберите нужный микроконтроллер (например, ATMega для принтеров на базе Arduino) и завершите.
make || error_exit "Компиляция прошивки"

echo "Настройка службы Klipper для автозагрузки..."
pause
cp ~/klipper/scripts/klipper.service /etc/systemd/system/ || error_exit "Копирование klipper.service"
systemctl enable klipper.service || error_exit "Добавление klipper.service в автозагрузку"
systemctl start klipper.service || error_exit "Запуск klipper.service"

echo "Загрузка веб-интерфейса Mainsail..."
pause
cd ~
wget https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip || error_exit "Загрузка Mainsail"
unzip mainsail.zip -d ~/mainsail || error_exit "Распаковка Mainsail"

echo "Установка и настройка nginx для Mainsail..."
pause
apt install -y nginx || error_exit "Установка nginx"
rm /etc/nginx/sites-enabled/default || error_exit "Удаление стандартной конфигурации nginx"
cat << 'EOF' | tee /etc/nginx/sites-available/mainsail || error_exit "Создание конфигурации для Mainsail"
server {
    listen 80 default_server;
    server_name _;

    root /home/$USER/mainsail;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    location /webcam/ {
        proxy_pass http://localhost:8080/;
    }
}
EOF

echo "Активация конфигурации Mainsail в nginx..."
pause
ln -s /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/mainsail || error_exit "Создание символической ссылки для Mainsail в nginx"
systemctl restart nginx || error_exit "Перезапуск nginx"

echo "Создание службы для автозагрузки Mainsail..."
pause
cat << 'EOF' | tee /etc/systemd/system/mainsail.service || error_exit "Создание mainsail.service"
[Unit]
Description=Mainsail Web Interface
After=network.target klipper.service

[Service]
Type=simple
WorkingDirectory=/home/$USER/mainsail
ExecStart=/usr/bin/python3 -m http.server --directory /home/$USER/mainsail 8080
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF

echo "Включение автозагрузки для Mainsail..."
pause
systemctl enable mainsail.service || error_exit "Добавление mainsail.service в автозагрузку"
systemctl start mainsail.service || error_exit "Запуск mainsail.service"

# Определение IP-адреса устройства
IP_ADDRESS=$(hostname -I | awk '{print $1}') || error_exit "Определение IP-адреса"

# Завершающее сообщение
echo "Установка Klipper и Mainsail завершена."
echo "Запустите браузер и перейдите на http://$IP_ADDRESS, чтобы управлять принтером через Mainsail."

