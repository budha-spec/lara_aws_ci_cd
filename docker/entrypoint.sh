#!/bin/bash

set -e

echo "======================================"
echo "LARAVEL CONTAINER STARTING"
echo "======================================"

# ------------------------------------------------------------
# Required environment
# ------------------------------------------------------------

if [ -z "${APP_KEY:-}" ]; then
    echo "ERROR: APP_KEY is missing."
    exit 1
fi

echo "APP_KEY: PRESENT"
echo "APP_KEY length: ${#APP_KEY}"

if [ -z "${APP_ENV:-}" ]; then
    echo "WARNING: APP_ENV is not set."
else
    echo "APP_ENV: ${APP_ENV}"
fi

if [ -z "${APP_URL:-}" ]; then
    echo "WARNING: APP_URL is not set."
else
    echo "APP_URL: ${APP_URL}"
fi

# ------------------------------------------------------------
# Laravel writable directories
# ------------------------------------------------------------

mkdir -p \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache

chown -R www-data:www-data \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache

chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache

# ------------------------------------------------------------
# Clear old Laravel caches
# ------------------------------------------------------------

echo "Clearing Laravel caches..."

php artisan optimize:clear

# ------------------------------------------------------------
# Optional production config cache
# ------------------------------------------------------------

echo "Caching Laravel configuration..."

php artisan config:cache

echo "Laravel configuration cached."

# ------------------------------------------------------------
# Start Supervisor
# ------------------------------------------------------------

echo "======================================"
echo "STARTING SUPERVISOR"
echo "======================================"

exec "$@"
