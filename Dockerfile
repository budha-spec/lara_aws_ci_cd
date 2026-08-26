# ============================================================
# STAGE 1: FRONTEND / VITE
# ============================================================

FROM node:22-alpine AS frontend

WORKDIR /app

# ------------------------------------------------------------
# Package files
# ------------------------------------------------------------

COPY package.json package-lock.json ./

# ------------------------------------------------------------
# Install exact dependencies
# ------------------------------------------------------------

RUN npm ci

# ------------------------------------------------------------
# Frontend source
# ------------------------------------------------------------

COPY resources ./resources
COPY public ./public
COPY vite.config.js ./

# ------------------------------------------------------------
# Production build
# ------------------------------------------------------------

ENV NODE_ENV=production

RUN rm -f public/hot \
    && npm run build

# ------------------------------------------------------------
# Verify Vite build
# ------------------------------------------------------------

RUN test -d /app/public/build \
    && test -f /app/public/build/manifest.json \
    && test ! -f /app/public/hot

RUN echo "======================================"
RUN echo "VITE BUILD"
RUN echo "======================================"

RUN find /app/public/build \
    -maxdepth 3 \
    -type f \
    -print \
    | sort


# ============================================================
# STAGE 2: COMPOSER DEPENDENCIES
# ============================================================

FROM composer:2 AS composer

WORKDIR /app

# ------------------------------------------------------------
# Composer files
# ------------------------------------------------------------

COPY composer.json composer.lock ./

# ------------------------------------------------------------
# Install production dependencies
# ------------------------------------------------------------

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
# SYSTEM PACKAGES
# ============================================================

RUN apk add --no-cache \
    nginx \
    supervisor \
    bash \
    curl \
    git \
    unzip \
    tzdata \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    mariadb-connector-c-dev

# ============================================================
# PHP EXTENSIONS
# ============================================================

RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo \
        pdo_mysql \
        mbstring \
        bcmath \
        intl \
        zip \
        opcache \
        gd \
    && apk del \
        icu-dev \
        libzip-dev \
        oniguruma-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev

# ============================================================
# PHP PRODUCTION CONFIGURATION
# ============================================================

RUN cp "$PHP_INI_DIR/php.ini-production" \
       "$PHP_INI_DIR/php.ini"

# ============================================================
# PHP OPCACHE
# ============================================================

RUN cat > /usr/local/etc/php/conf.d/99-production.ini <<'EOF'
opcache.enable=1
opcache.enable_cli=1
opcache.validate_timestamps=0
opcache.revalidate_freq=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000

expose_php=Off
memory_limit=256M
upload_max_filesize=50M
post_max_size=50M
max_execution_time=300
EOF

# ============================================================
# PHP-FPM
# ============================================================

RUN sed -i 's|^listen = 9000|listen = 127.0.0.1:9000|' \
    /usr/local/etc/php-fpm.d/www.conf

RUN sed -i 's|^;clear_env = no|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf

RUN sed -i 's|^clear_env = yes|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf

# ------------------------------------------------------------
# PHP-FPM environment
#
# These values are supplied at container runtime by
# Elastic Beanstalk / Docker.
#
# DO NOT put secrets into the Dockerfile.
# ------------------------------------------------------------

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
# NGINX
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

# ------------------------------------------------------------
# Remove any config cache copied from source
# ------------------------------------------------------------

RUN rm -f \
    bootstrap/cache/config.php \
    bootstrap/cache/packages.php \
    bootstrap/cache/services.php

# ============================================================
# COMPOSER DEPENDENCIES
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

# ------------------------------------------------------------
# Never ship development hot file
# ------------------------------------------------------------

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
# LARAVEL OPTIMIZATION
#
# IMPORTANT:
# Do not run config:cache here.
#
# APP_KEY / DB credentials are supplied at runtime.
# ============================================================

RUN php artisan optimize:clear

# ============================================================
# BUILD-TIME VALIDATION
# ============================================================

RUN echo "======================================"
RUN echo "LARAVEL BUILD VALIDATION"
RUN echo "======================================"

RUN test -f public/index.php
RUN test -d public/build
RUN test -f public/build/manifest.json
RUN test ! -f public/hot

RUN echo "Laravel application: OK"
RUN echo "Vite build: OK"
RUN echo "Vite manifest: OK"
RUN echo "Vite hot file: NOT PRESENT"

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
# REMOVE UNNECESSARY FILES
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
