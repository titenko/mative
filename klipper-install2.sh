#!/bin/bash

# ===============================
# Переменные
# ===============================
KLIPPER_DIR="$HOME/klipper"
MAINSAIL_DIR="$HOME/mainsail"
MAINSAIL_ZIP="mainsail.zip"
NGINX_CONF="/etc/nginx/sites-available/mainsail"

# ===============================
# Проверка прав доступа (sudo)
# ===============================
if [ "$EUID" -ne 0 ]; then
    echo "Скрипт требует права суперпользователя. Запрашиваем пароль для повышения прав..."
    sudo "$0" "$@"
    exit
fi

# ===============================
# Функции
# ===============================

# Логирование в файл
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a install.log
}

# Проверка подключения к интернету
check_internet() {
    log "Проверка подключения к интернету..."
    wget -q --spider http://google.com
    if [ $? -ne 0 ]; then
        log "Нет подключения к интернету. Пожалуйста, подключитесь к интернету и перезапустите скрипт."
        exit 1
    fi
}

# Установка пакетов, если их нет
install_packages() {
    log "Установка необходимых пакетов..."
    apt update && apt install -y \
        git python3 python3-virtualenv python3-dev build-essential libffi-dev libncurses-dev \
        libusb-dev avrdude gcc-avr binutils-avr avr-libc stm32flash dfu-util unzip nginx || error_exit "Установка пакетов"
}

# Клонирование репозитория Klipper
setup_klipper() {
    if [ ! -d "$KLIPPER_DIR" ]; then
        log "Клонирование репозитория Klipper..."
        git clone https://github.com/Klipper3d/klipper.git "$KLIPPER_DIR" || error_exit "Клонирование репозитория Klipper"
    else
        log "Папка Klipper уже существует. Пропуск клонирования."
    fi

    log "Настройка виртуального окружения для Klipper..."
    cd "$KLIPPER_DIR"
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r scripts/klippy-requirements.txt || error_exit "Установка зависимостей для Klipper"
}

# Настройка службы
enable_service() {
    local service_name=$1
    systemctl enable "$service_name" || error_exit "Добавление $service_name в автозагрузку"
    systemctl start "$service_name" || error_exit "Запуск $service_name"
}

# Настройка NGINX
setup_nginx() {
    log "Настройка NGINX для Mainsail..."
    rm -f /etc/nginx/sites-enabled/default
    cat << EOF | tee "$NGINX_CONF"
server {
    listen 80 default_server;
    server_name _;

    root $MAINSAIL_DIR;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }

    location /webcam/ {
        proxy_pass http://localhost:8080/;
    }
}
EOF
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/mainsail
    systemctl restart nginx || error_exit "Перезапуск nginx"
}

# Проверка наличия и установка Mainsail
setup_mainsail() {
    if [ ! -d "$MAINSAIL_DIR" ]; then
        log "Загрузка и установка Mainsail..."
        wget -q https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip -O "$MAINSAIL_ZIP" || error_exit "Загрузка Mainsail"
        unzip -q "$MAINSAIL_ZIP" -d "$MAINSAIL_DIR" || error_exit "Распаковка Mainsail"
        rm "$MAINSAIL_ZIP"
    else
        log "Папка Mainsail уже существует. Пропуск загрузки."
    fi
}

# Создание службы для Mainsail
create_mainsail_service() {
    log "Создание службы для Mainsail..."
    cat << EOF | tee /etc/systemd/system/mainsail.service
[Unit]
Description=Mainsail Web Interface
After=network.target klipper.service

[Service]
Type=simple
WorkingDirectory=$MAINSAIL_DIR
ExecStart=/usr/bin/python3 -m http.server --directory $MAINSAIL_DIR 8080
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF
    enable_service mainsail.service
}

# ===============================
# Основной процесс
# ===============================

log "Начало установки Klipper и Mainsail..."
pause() { sleep 3; }

check_internet
install_packages

setup_klipper
pause

log "Настройка и компиляция прошивки для Klipper..."
cd "$KLIPPER_DIR"
make menuconfig || error_exit "Запуск menuconfig"
make || error_exit "Компиляция прошивки"
enable_service klipper.service
pause

setup_mainsail
setup_nginx
create_mainsail_service
pause

# Определение IP-адреса устройства
IP_ADDRESS=$(hostname -I | awk '{print $1}') || error_exit "Определение IP-адреса"

log "Установка завершена. Перейдите на http://$IP_ADDRESS для доступа к веб-интерфейсу Mainsail."

