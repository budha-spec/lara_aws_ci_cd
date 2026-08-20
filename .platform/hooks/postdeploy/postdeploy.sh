#!/bin/bash
set -e

APP_DIR="/var/app/current"

if [ ! -d "$APP_DIR" ]; then
    echo "Directory not found: $APP_DIR"
    exit 1
fi

cd "$APP_DIR"

echo "Clearing Laravel cache..."

php artisan optimize:clear

echo "Running database migrations..."

php artisan migrate --force

echo "Post-deployment completed successfully."