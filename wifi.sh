#!/bin/bash

# Проверка наличия необходимых инструментов
if ! command -v nmcli &> /dev/null
then
    echo "nmcli не установлен. Пожалуйста, установите его и попробуйте снова."
    exit 1
fi

# Получение списка доступных Wi-Fi сетей
echo "Сканирую доступные сети Wi-Fi..."
nmcli device wifi rescan
networks=$(nmcli -t -f SSID,SECURITY device wifi list | grep -v '^--' | awk -F: '{print NR". "$1" ("$2")"}')

# Проверка, найдено ли что-то
if [ -z "$networks" ]; then
    echo "Не найдено доступных Wi-Fi сетей."
    exit 1
fi

# Показ списка сетей и выбор пользователем
echo "Доступные сети:"
echo "$networks"
echo "Введите номер сети для подключения:"
read -r network_number

# Получение SSID выбранной сети
ssid=$(echo "$networks" | sed -n "${network_number}p" | awk -F' ' '{print $2}')

if [ -z "$ssid" ]; then
    echo "Неверный выбор сети."
    exit 1
fi

# Запрос пароля от Wi-Fi
echo "Введите пароль для сети '$ssid':"
read -s wifi_password

# Попытка подключения
echo "Подключаюсь к сети $ssid..."
nmcli device wifi connect "$ssid" password "$wifi_password"

# Проверка успешности подключения
if [ $? -eq 0 ]; then
    echo "Успешное подключение к сети '$ssid'."
    echo "Создание автоматического подключения для сети '$ssid'..."
    nmcli connection modify "$ssid" wifi-sec.key-mgmt wpa-psk
    nmcli connection modify "$ssid" wifi-sec.psk "$wifi_password"
    nmcli connection up "$ssid"
    echo "Автоматическое подключение к сети '$ssid' создано."
else
    echo "Не удалось подключиться к сети '$ssid'. Пожалуйста, проверьте пароль и попробуйте снова."
fi

