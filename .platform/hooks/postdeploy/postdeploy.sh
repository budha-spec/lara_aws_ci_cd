set -e

APP_DIR = "/var/app/staging"

if [! -dir "$APP_DIR"]; then
    echo "Directory not found: $APP_DIR"
    exit 1
fi

cd "$APP_DIR"

echo "Clear all Cache"

php artisan optimize:clear

echo "Run migration"

php artisan migrate --force