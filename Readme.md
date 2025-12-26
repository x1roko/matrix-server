# Matrix Server Deployment (Synapse + LiveKit + Coturn)

Этот проект позволяет быстро развернуть полноценный сервер Matrix с поддержкой современных видеовызовов (через LiveKit) и обходом NAT (через Coturn).

## Структура проекта

* **Synapse**: Основной сервер Matrix.
* **PostgreSQL**: База данных.
* **Coturn**: TURN/STUN сервер для звонков.
* **LiveKit**: SFU сервер для групповых аудио/видео конференций.
* **Caddy**: Реверс-прокси для маршрутизации трафика и автоматический SSL.

## Предварительные требования

1. Установленные `docker` и `docker-compose`.
2. Домен, направленный на IP вашего сервера.

## Инструкция

1. **Подготовьте домен**: Направьте `your-domain.com`, `matrix.your-domain.com` и `livekit.your-domain.com` на IP сервера.

2. **Запустите скрипт настройки:**
   ```bash
   chmod +x setup.sh
   ./setup.sh

## Запуск

```docker-compose up -d```

## Для создания пользователя

```docker exec -it matrix-synapse-1 register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008```

## Важные порты для работы

* 80/443: Веб и API.
* 8448: Федерация (общение с другими серверами).
* 3478 (UDP/TCP): Coturn.
* 50000-50050 (UDP): LiveKit RTC.
