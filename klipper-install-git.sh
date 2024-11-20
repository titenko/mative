#!/bin/bash

# Проверка на root права
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами sudo."
    sudo "$0" "$@"  # Перезапуск скрипта с sudo
    exit 0
fi

# Обновление пакетов и установка git
sudo apt-get update && sudo apt-get install git -y

# Клонирование репозитория
git clone https://github.com/dw-0/kiauh.git

# Запуск скрипта
./kiauh/kiauh.sh

