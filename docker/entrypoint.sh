#!/bin/sh

set -eu

echo "======================================"
echo "LARAVEL CONTAINER STARTING"
echo "======================================"

if [ -z "${APP_KEY:-}" ]; then
    echo "ERROR: APP_KEY is missing."
    exit 1
fi

echo "APP_KEY: PRESENT"
echo "APP_ENV: ${APP_ENV:-not-set}"

# Clear runtime caches
php artisan optimize:clear

# Cache configuration using runtime environment variables
php artisan config:cache

# Cache routes if your application supports it
php artisan route:cache || true

# Cache views
php artisan view:cache || true

echo "======================================"
echo "LARAVEL READY"
echo "======================================"

exec "$@"
