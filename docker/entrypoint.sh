#!/usr/bin/env bash

set -e

echo "======================================"
echo "LARAVEL CONTAINER STARTING"
echo "======================================"

# ------------------------------------------------------------
# If Docker is being used for inspection/debugging, do not
# require Laravel runtime environment variables.
#
# Example:
# docker run --rm --entrypoint sh IMAGE
# ------------------------------------------------------------

if [ "$#" -gt 0 ] && [ "$1" != "supervisord" ]; then
    exec "$@"
fi


# ------------------------------------------------------------
# Runtime environment validation
# ------------------------------------------------------------

if [ -z "${APP_KEY:-}" ]; then
    echo "ERROR: APP_KEY is missing."
    echo "APP_KEY must be supplied as a runtime environment variable."
    exit 1
fi

if [ -z "${APP_ENV:-}" ]; then
    export APP_ENV=production
fi

if [ -z "${APP_DEBUG:-}" ]; then
    export APP_DEBUG=false
fi


# ------------------------------------------------------------
# Laravel runtime directories
# ------------------------------------------------------------

mkdir -p \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache


# ------------------------------------------------------------
# Permissions
# ------------------------------------------------------------

chown -R www-data:www-data \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache

chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache


# ------------------------------------------------------------
# Clear old runtime cache
# ------------------------------------------------------------

php artisan optimize:clear


# ------------------------------------------------------------
# Cache Laravel configuration at RUNTIME
#
# This is important because APP_KEY, DB credentials, etc.
# are available here.
# ------------------------------------------------------------

php artisan config:cache


# ------------------------------------------------------------
# Start container command
# ------------------------------------------------------------

echo "APP_ENV: ${APP_ENV}"
echo "APP_DEBUG: ${APP_DEBUG}"
echo "APP_KEY: PRESENT"
echo "======================================"

exec "$@"
