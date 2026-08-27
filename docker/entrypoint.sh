#!/bin/sh

set -e

echo "======================================"
echo "LARAVEL CONTAINER STARTING"
echo "======================================"

echo "APP_ENV=${APP_ENV}"
echo "DB_HOST=${DB_HOST}"
echo "DB_PORT=${DB_PORT}"
echo "DB_DATABASE=${DB_DATABASE}"

echo "Waiting for RDS..."

until nc -z "$DB_HOST" "$DB_PORT"; do
    echo "RDS not reachable yet..."
    sleep 5
done

echo "RDS TCP connection available."

php artisan config:clear
php artisan config:cache

php artisan migrate --force

echo "Laravel startup complete."

exec "$@"
