#!/bin/sh

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

exec "$@"
