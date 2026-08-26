#!/bin/sh

set -eu

echo "======================================"
echo "LARAVEL CONTAINER STARTING"
echo "======================================"

# ------------------------------------------------------------
# Production safety
# ------------------------------------------------------------

rm -f /var/www/html/public/hot

# ------------------------------------------------------------
# Verify APP_KEY
# ------------------------------------------------------------

if [ -z "${APP_KEY:-}" ]; then
    echo "ERROR: APP_KEY is missing."
    exit 1
fi

echo "APP_KEY: PRESENT"

# ------------------------------------------------------------
# Verify Vite production build
# ------------------------------------------------------------

if [ ! -f /var/www/html/public/build/manifest.json ]; then
    echo "ERROR: Vite manifest is missing."
    exit 1
fi

if [ -f /var/www/html/public/hot ]; then
    echo "ERROR: Vite hot file exists."
    exit 1
fi

echo "Vite production build: PRESENT"
echo "Vite hot file: NOT PRESENT"

# ------------------------------------------------------------
# Laravel storage
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

# ------------------------------------------------------------
# Laravel migrations
#
# Uncomment only if you want every EB container startup
# to execute migrations.
# ------------------------------------------------------------

# php artisan migrate --force

# ------------------------------------------------------------
# Start Supervisor
# ------------------------------------------------------------

echo "======================================"
echo "STARTING NGINX + PHP-FPM"
echo "======================================"

exec /usr/bin/supervisord \
    -c /etc/supervisord.conf
