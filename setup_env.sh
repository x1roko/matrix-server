#!/bin/bash

# Функция для генерации случайной строки
generate_secret() {
    openssl rand -hex 24
}

# Путь к файлу .env
ENV_FILE=".env"

# Проверяем, существует ли уже файл, чтобы не перезаписать его случайно
if [ -f "$ENV_FILE" ]; then
    echo "Файл $ENV_FILE уже существует. Сделайте бэкап или удалите его, если хотите создать новый."
    exit 1
fi

echo "Генерация конфигурации .env..."

# Получаем внешний IP сервера автоматически
SERVER_IP=$(curl -s https://ifconfig.me)

cat << EOF > $ENV_FILE
# --- БАЗА ДАННЫХ ---
DB_PASSWORD=$(generate_secret)

# --- LIVEKIT ---
LIVEKIT_KEY=devkey
LIVEKIT_SECRET=$(generate_secret)

# --- ДОМЕН И СЕТЬ ---
DOMAIN=dreamnode.fun
EXTERNAL_IP=$SERVER_IP
EOF

echo "Готово! Файл $ENV_FILE создан."
echo "Ваш внешний IP определен как: $SERVER_IP"
echo "ОБЯЗАТЕЛЬНО проверьте содержимое файла: cat .env"
