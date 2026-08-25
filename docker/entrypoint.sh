#!/bin/sh

set -e

echo "======================================"
echo "CONTAINER STARTUP"
echo "======================================"

echo "APP_ENV: ${APP_ENV:-MISSING}"

if [ -n "$APP_KEY" ]; then
    echo "APP_KEY: PRESENT"
    echo "APP_KEY length: ${#APP_KEY}"
else
    echo "APP_KEY: MISSING"
fi

echo "======================================"
echo "VITE ASSETS"
echo "======================================"

if [ -f /var/www/html/public/build/manifest.json ]; then
    echo "Vite manifest: PRESENT"
else
    echo "Vite manifest: MISSING"
fi

echo "======================================"
echo "LARAVEL"
echo "======================================"

php artisan about || true

echo "======================================"
echo "STARTING SERVICES"
echo "======================================"

cd /var/www/html

exec "$@"
