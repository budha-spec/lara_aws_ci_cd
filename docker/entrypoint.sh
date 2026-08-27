#!/bin/sh

set -eu

echo "======================================"
echo "LARAVEL CONTAINER STARTING"
echo "======================================"

echo "APP_ENV=${APP_ENV:-}"
echo "DB_HOST=${DB_HOST:-}"
echo "DB_PORT=${DB_PORT:-3306}"
echo "DB_DATABASE=${DB_DATABASE:-}"
echo "DB_USERNAME=${DB_USERNAME:-}"

if [ -z "${DB_HOST:-}" ]; then
    echo "ERROR: DB_HOST is not set"
    exit 1
fi

echo "Waiting for RDS..."

MAX_RETRIES=60
RETRY=0

until nc -z "$DB_HOST" "$DB_PORT"; do
    RETRY=$((RETRY + 1))

    echo "RDS not reachable yet... attempt ${RETRY}/${MAX_RETRIES}"

    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        echo "ERROR: RDS is not reachable."
        exit 1
    fi

    sleep 5
done

echo "RDS TCP connection available."

echo "Clearing Laravel cache..."
php artisan optimize:clear

echo "Caching Laravel configuration..."
php artisan config:cache

echo "Running migrations..."
php artisan migrate --force

echo "Laravel startup complete."

exec "$@"
