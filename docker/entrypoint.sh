#!/bin/sh

set -e

echo "======================================"
echo "Container environment check"
echo "======================================"

if [ -n "$APP_KEY" ]; then
    echo "APP_KEY: PRESENT"
    echo "APP_KEY length: ${#APP_KEY}"
else
    echo "APP_KEY: MISSING"
fi

echo "======================================"
echo "PHP-FPM environment configuration"
echo "======================================"

grep -R "clear_env" /usr/local/etc/php-fpm.d/ || true

echo "======================================"
echo "Laravel"
echo "======================================"

cd /var/www/html

exec "$@"
