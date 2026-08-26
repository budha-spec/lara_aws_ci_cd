# ============================================================
# STAGE 1: VITE
# ============================================================

FROM node:22-alpine AS frontend

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY resources ./resources
COPY public ./public
COPY vite.config.js ./

ENV NODE_ENV=production

RUN rm -f public/hot \
    && npm run build \
    && test -f public/build/manifest.json \
    && test ! -f public/hot


# ============================================================
# STAGE 2: COMPOSER
# ============================================================

FROM composer:2 AS composer

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts


# ============================================================
# STAGE 3: PHP APPLICATION
# ============================================================

FROM php:8.3-fpm-alpine

WORKDIR /var/www/html


# ============================================================
# SYSTEM RUNTIME PACKAGES
# ============================================================

RUN apk add --no-cache \
    nginx \
    supervisor \
    bash \
    curl \
    ca-certificates \
    git \
    unzip \
    tzdata \
    libpng \
    libjpeg-turbo \
    freetype \
    icu-libs \
    libzip \
    oniguruma \
    libpq


# ============================================================
# PHP EXTENSION BUILD DEPENDENCIES
# ============================================================

RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
    postgresql-dev


# ============================================================
# PHP EXTENSIONS
# ============================================================

RUN set -eux; \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
        bcmath \
        gd \
        intl \
        zip \
        opcache


# ============================================================
# REMOVE BUILD DEPENDENCIES
# ============================================================

RUN apk del .build-deps \
    && rm -rf /tmp/*


# ============================================================
# PHP PRODUCTION CONFIG
# ============================================================

RUN mv \
    "$PHP_INI_DIR/php.ini-production" \
    "$PHP_INI_DIR/php.ini"


# ============================================================
# PHP CONFIGURATION
# ============================================================

RUN cat > /usr/local/etc/php/conf.d/99-production.ini <<'EOF'
expose_php=Off

memory_limit=256M

upload_max_filesize=50M
post_max_size=50M

max_execution_time=300
max_input_time=300

opcache.enable=1
opcache.enable_cli=1
opcache.validate_timestamps=0
opcache.revalidate_freq=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
EOF


# ============================================================
# PHP-FPM
# ============================================================

RUN sed -i \
    's|^listen = 9000|listen = 127.0.0.1:9000|' \
    /usr/local/etc/php-fpm.d/www.conf

RUN sed -i \
    's|^;clear_env = no|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf

RUN sed -i \
    's|^clear_env = yes|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf


# ============================================================
# PHP-FPM ENVIRONMENT
# ============================================================

RUN cat > /usr/local/etc/php-fpm.d/99-environment.conf <<'EOF'
[www]

clear_env = no

env[APP_ENV] = $APP_ENV
env[APP_DEBUG] = $APP_DEBUG
env[APP_KEY] = $APP_KEY
env[APP_URL] = $APP_URL

env[LOG_CHANNEL] = $LOG_CHANNEL
env[LOG_LEVEL] = $LOG_LEVEL

env[DB_CONNECTION] = $DB_CONNECTION
env[DB_HOST] = $DB_HOST
env[DB_PORT] = $DB_PORT
env[DB_DATABASE] = $DB_DATABASE
env[DB_USERNAME] = $DB_USERNAME
env[DB_PASSWORD] = $DB_PASSWORD

env[CACHE_STORE] = $CACHE_STORE
env[SESSION_DRIVER] = $SESSION_DRIVER
env[QUEUE_CONNECTION] = $QUEUE_CONNECTION
EOF


# ============================================================
# NGINX DIRECTORIES
# ============================================================

RUN mkdir -p \
    /run/nginx \
    /var/cache/nginx \
    /var/log/nginx


# ============================================================
# NGINX CONFIG
# ============================================================

RUN rm -f /etc/nginx/http.d/default.conf

COPY docker/nginx/default.conf \
    /etc/nginx/http.d/default.conf


# ============================================================
# SUPERVISOR
# ============================================================

COPY docker/supervisor/supervisord.conf \
    /etc/supervisord.conf


# ============================================================
# APPLICATION
# ============================================================

COPY . .


# ============================================================
# REMOVE BUILD-TIME LARAVEL CACHE
# ============================================================

RUN rm -f \
    bootstrap/cache/config.php \
    bootstrap/cache/packages.php \
    bootstrap/cache/services.php


# ============================================================
# COMPOSER VENDOR
# ============================================================

COPY --from=composer \
    /app/vendor \
    /var/www/html/vendor


# ============================================================
# VITE BUILD
# ============================================================

COPY --from=frontend \
    /app/public/build \
    /var/www/html/public/build


# ============================================================
# REMOVE VITE HOT FILE
# ============================================================

RUN rm -f \
    /var/www/html/public/hot


# ============================================================
# LARAVEL DIRECTORIES
# ============================================================

RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache


# ============================================================
# PERMISSIONS
# ============================================================

RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache \
    public

RUN chmod -R 775 \
    storage \
    bootstrap/cache


# ============================================================
# LARAVEL CACHE
# ============================================================

RUN php artisan optimize:clear


# ============================================================
# PHP VALIDATION
# ============================================================

RUN php -v

RUN php -m


# ============================================================
# APPLICATION VALIDATION
# ============================================================

RUN test -f public/index.php

RUN test -f public/build/manifest.json

RUN test ! -f public/hot


# ============================================================
# NGINX VALIDATION
# ============================================================

RUN nginx -t


# ============================================================
# PHP-FPM VALIDATION
# ============================================================

RUN php-fpm -t


# ============================================================
# ENTRYPOINT
# ============================================================

COPY docker/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x \
    /usr/local/bin/entrypoint.sh


# ============================================================
# CLEANUP
# ============================================================

RUN rm -rf \
    /tmp/* \
    /root/.cache \
    /root/.composer


# ============================================================
# PORT
# ============================================================

EXPOSE 80


# ============================================================
# START
# ============================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf"]

