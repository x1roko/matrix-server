#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Полная автоматическая настройка Matrix + LiveKit + Caddy${NC}"

read -p "Введите ваш домен (например, dreamnode.fun): " DOMAIN
if [ -z "$DOMAIN" ]; then 
    echo -e "${RED}Домен не введен. Выход.${NC}"
    exit 1
fi

# 1. Генерация всех секретов
COTURN_SECRET=$(openssl rand -hex 32)
REG_SECRET=$(openssl rand -hex 32)
MACAROON=$(openssl rand -hex 32)
FORM_SEC=$(openssl rand -hex 32)
LK_API_KEY="lk_key_$(openssl rand -hex 4)"
LK_API_SECRET=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)

# 2. Создание структуры папок
mkdir -p synapse coturn livekit

# 3. Создание .env для docker-compose
echo "DB_PASSWORD=$DB_PASSWORD" > .env
echo "DOMAIN=$DOMAIN" >> .env

# 4. Генерация ключей Synapse (signing.key), если их нет
if [ ! -f "synapse/$DOMAIN.signing.key" ]; then
    echo "Генерация ключей Synapse..."
    docker run --rm -v "$PWD/synapse:/data" -e SYNAPSE_SERVER_NAME=$DOMAIN matrixdotorg/synapse:latest generate
fi

# 5. Создание правильного homeserver.yaml
cat <<EOF > synapse/homeserver.yaml
server_name: "$DOMAIN"
pid_file: /data/homeserver.pid
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false

database:
  name: psycopg2
  args:
    user: synapse
    password: $DB_PASSWORD
    database: synapse
    host: db
    cp_min: 5
    cp_max: 10

log_config: "/data/$DOMAIN.log.config"
media_store_path: /data/media_store
enable_registration: true
enable_registration_without_verification: true
registration_shared_secret: "$REG_SECRET"
macaroon_secret_key: "$MACAROON"
form_secret: "$FORM_SEC"
signing_key_path: "/data/$DOMAIN.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"

turn_uris: ["turn:$DOMAIN:3478?transport=udp", "turn:$DOMAIN:3478?transport=tcp"]
turn_shared_secret: "$COTURN_SECRET"
turn_user_lifetime: 86400000

matrix_rtc:
  enabled: true
  active_foci:
    - type: livekit
      livekit_service_url: "https://livekit.$DOMAIN"
      livekit_api_key: "$LK_API_KEY"
      livekit_api_secret: "$LK_API_SECRET"

experimental_features:
  msc4143_enabled: true
EOF

# 6. Исправленный Caddyfile
cat <<EOF > Caddyfile
{
    email x1roko.dev@gmail.com
}

$DOMAIN {
    # .well-known для федерации
    handle_path /.well-known/matrix/server {
        header Access-Control-Allow-Origin "*"
        header Content-Type application/json
        respond \`{"m.server": "matrix.$DOMAIN:443"}\`
    }

    # .well-known для клиента
    handle_path /.well-known/matrix/client {
        header Access-Control-Allow-Origin "*"
        header Content-Type application/json
        respond \`{"m.homeserver":{"base_url":"https://matrix.$DOMAIN"},"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://livekit.$DOMAIN"}]}\`
    }

    # Заглушка для основного домена
    respond "Welcome to $DOMAIN" 200
}

matrix.$DOMAIN {
    reverse_proxy synapse:8008
}

$DOMAIN:8448 {
    reverse_proxy synapse:8008
}

livekit.$DOMAIN {
    reverse_proxy livekit:7880 {
        header_up Upgrade {http_upgrade}
        header_up Connection "Upgrade"
    }
}
EOF

# 7. Настройка Coturn
cat <<EOF > coturn/turnserver.conf
listening-port=3478
fingerprint
use-auth-secret
static-auth-secret=$COTURN_SECRET
realm=$DOMAIN
EOF

# 8. Настройка LiveKit
cat <<EOF > livekit/livekit.yaml
port: 7880
rtc:
    use_external_ip: true
keys:
    "$LK_API_KEY": "$LK_API_SECRET"
EOF

# 9. Установка прав (КРИТИЧНО)
sudo chown -R 991:991 synapse/

echo -e "${GREEN}Настройка завершена!${NC}"
echo -e "Проверьте DNS в Cloudflare (A записи для: $DOMAIN, matrix.$DOMAIN, livekit.$DOMAIN)"
echo -e "Запустите команду: ${GREEN}docker compose down && docker compose up -d${NC}"
