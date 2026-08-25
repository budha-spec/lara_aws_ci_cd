#!/bin/bash

echo "===== Laravel APP_KEY diagnostic ====="

if [ -z "$APP_KEY" ]; then
    echo "EB APP_KEY: MISSING"
else
    echo "EB APP_KEY: PRESENT"
    echo "EB APP_KEY length: ${#APP_KEY}"
fi