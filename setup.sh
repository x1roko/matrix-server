#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Настройка Matrix + LiveKit + Caddy${NC}"

read -p "Введите ваш домен (example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then exit 1; fi

# Генерация секретов
COTURN_SECRET=$(openssl rand -hex 32)
REG_SECRET=$(openssl rand -hex 32)
MACAROON=$(openssl rand -hex 32)
FORM_SEC=$(openssl rand -hex 32)
LK_API_KEY=$(openssl rand -hex 16)
LK_API_SECRET=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)

# 1. Создание .env для docker-compose
echo "DB_PASSWORD=$DB_PASSWORD" > .env

# 2. Генерация Synapse (начальная)
mkdir -p synapse
docker run --rm -v "$PWD/synapse:/data" -e SYNAPSE_SERVER_NAME=$DOMAIN -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:latest generate

# 3. Создание homeserver.yaml
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

# 4. Создание Caddyfile
cat <<EOF > Caddyfile
$DOMAIN, www.$DOMAIN {
    # Matrix Well-Known
    handle_path /.well-known/matrix/* {
        header Access-Control-Allow-Origin "*"
        header Content-Type "application/json"
        respond /server \`{"m.server": "matrix.$DOMAIN:443"}\`
        respond /client \`{"m.homeserver":{"base_url":"https://matrix.$DOMAIN"},"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://livekit.$DOMAIN"}]}\`
    }
}

matrix.$DOMAIN {
    reverse_proxy synapse:8008
}

$DOMAIN:8448 {
    reverse_proxy synapse:8008
}

livekit.$DOMAIN {
    reverse_proxy livekit:7880
}
EOF

# 5. Настройка Coturn и LiveKit
mkdir -p coturn livekit
echo "listening-port=3478
fingerprint
use-auth-secret
static-auth-secret=$COTURN_SECRET
realm=$DOMAIN" > coturn/turnserver.conf

echo "port: 7880
rtc:
  use_external_ip: true
keys:
    \"$LK_API_KEY\": \"$LK_API_SECRET\"" > livekit/livekit.yaml

echo -e "${GREEN}Настройка завершена. Запустите: docker-compose up -d${NC}"
