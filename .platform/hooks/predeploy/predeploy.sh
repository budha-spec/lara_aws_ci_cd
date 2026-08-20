#!/bin/bash
set -e

APP_DIR="/var/app/staging"

if [ ! -d "$APP_DIR" ]; then
    echo "Directory not found: $APP_DIR"
    exit 1
fi

cd "$APP_DIR"

echo "Creating Laravel directories..."

mkdir -p bootstrap/cache

mkdir -p storage/framework/cache
mkdir -p storage/framework/cache/data
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/framework/testing
mkdir -p storage/logs

echo "Updating permissions..."

chown -R webapp:webapp storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "Permissions updated."