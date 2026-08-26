# ============================================================
# STAGE 1: FRONTEND / VITE
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
    && test -d public/build \
    && test -f public/build/manifest.json \
    && test ! -f public/hot


# ============================================================
# STAGE 2: COMPOSER DEPENDENCIES
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
# STAGE 3: PRODUCTION APPLICATION
# ============================================================

FROM php:8.3-fpm-alpine

WORKDIR /var/www/html


# ============================================================
# SYSTEM + RUNTIME LIBRARIES
#
# IMPORTANT:
# Keep the runtime libraries installed.
#
# GD    -> libpng, libjpeg-turbo, freetype
# INTL  -> icu-libs
# ZIP   -> libzip
# MySQL -> mariadb-connector-c
# ============================================================

RUN apk add --no-cache \
        nginx \
        supervisor \
        curl \
        ca-certificates \
        bash \
        tzdata \
        icu-libs \
        libzip \
        libpng \
        libjpeg-turbo \
        freetype \
        mariadb-connector-c \
    \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        icu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        oniguruma-dev \
    \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        mbstring \
        bcmath \
        gd \
        intl \
        zip \
        opcache \
    \
    && apk del .build-deps \
    \
    && rm -rf /tmp/*


# ============================================================
# VERIFY PHP EXTENSIONS
# ============================================================

RUN set -eux; \
    php -m | grep -qi '^gd$'; \
    php -m | grep -qi '^intl$'; \
    php -m | grep -qi '^zip$'; \
    php -m | grep -qi '^pdo_mysql$'; \
    php -m | grep -qi '^mbstring$'; \
    php -m | grep -qi '^bcmath$'; \
    php -m | grep -qi '^opcache$'


# ============================================================
# PHP PRODUCTION CONFIGURATION
# ============================================================

RUN cp "$PHP_INI_DIR/php.ini-production" \
       "$PHP_INI_DIR/php.ini"


# ============================================================
# PHP PRODUCTION SETTINGS
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
        /usr/local/etc/php-fpm.d/www.conf \
    \
    && sed -i \
        's|^clear_env = yes|clear_env = no|' \
        /usr/local/etc/php-fpm.d/www.conf \
    \
    && sed -i \
        's|^;clear_env = no|clear_env = no|' \
        /usr/local/etc/php-fpm.d/www.conf


# ============================================================
# PHP-FPM ENVIRONMENT
#
# Laravel receives these values from the container runtime.
#
# DO NOT put secrets into the Dockerfile.
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
# NGINX CONFIGURATION
# ============================================================

RUN rm -f /etc/nginx/http.d/default.conf

COPY docker/nginx/default.conf \
    /etc/nginx/http.d/default.conf


# ============================================================
# SUPERVISOR
# ============================================================

RUN mkdir -p /etc/supervisor.d

COPY docker/supervisor/supervisord.conf \
    /etc/supervisord.conf


# ============================================================
# APPLICATION SOURCE
# ============================================================

COPY . .


# ============================================================
# REMOVE BUILD-TIME LARAVEL CACHE
#
# Runtime environment variables must be used.
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
# VITE PRODUCTION BUILD
# ============================================================

COPY --from=frontend \
    /app/public/build \
    /var/www/html/public/build


# ============================================================
# REMOVE VITE HOT FILE
# ============================================================

RUN rm -f /var/www/html/public/hot


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
# LARAVEL PERMISSIONS
# ============================================================

RUN chown -R www-data:www-data \
        storage \
        bootstrap/cache \
        public \
    \
    && chmod -R 775 \
        storage \
        bootstrap/cache


# ============================================================
# CLEAR LARAVEL CACHE
#
# DO NOT RUN config:cache HERE.
#
# APP_KEY / DB credentials are runtime values.
# ============================================================

RUN php artisan optimize:clear


# ============================================================
# BUILD VALIDATION
# ============================================================

RUN set -eux; \
    test -f public/index.php; \
    test -d public/build; \
    test -f public/build/manifest.json; \
    test ! -f public/hot


# ============================================================
# VERIFY PHP EXTENSIONS AGAIN
# ============================================================

RUN set -eux; \
    php --version; \
    php -m | grep -qi '^gd$'; \
    php -m | grep -qi '^intl$'; \
    php -m | grep -qi '^zip$'; \
    php -m | grep -qi '^pdo_mysql$'; \
    php -m | grep -qi '^mbstring$'; \
    php -m | grep -qi '^bcmath$'; \
    php -m | grep -qi '^opcache$'


# ============================================================
# VERIFY EXTENSION DETAILS
# ============================================================

RUN php --ri gd > /dev/null \
    && php --ri intl > /dev/null \
    && php --ri zip > /dev/null


# ============================================================
# NGINX VALIDATION
# ============================================================

RUN nginx -t


# ============================================================
# RUNTIME ENTRYPOINT
# ============================================================

COPY docker/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh


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
