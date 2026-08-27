#!/bin/bash

echo "===== EB ENV DEBUG ====="

echo "APP_ENV=${APP_ENV:-}"
echo "DB_HOST=${DB_HOST:-}"
echo "DB_PORT=${DB_PORT:-}"
echo "DB_DATABASE=${DB_DATABASE:-}"
echo "DB_USERNAME=${DB_USERNAME:-}"

echo "===== EB ENVIRONMENT FILES ====="

env | grep -E '^(APP_ENV|DB_HOST|DB_PORT|DB_DATABASE|DB_USERNAME)=' || true
