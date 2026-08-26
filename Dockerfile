# ============================================================
# STAGE 1: VITE
# ============================================================

FROM node:22-alpine AS frontend

WORKDIR /var/www/html

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

ENV NODE_ENV=production

RUN rm -f public/hot

RUN test -f resources/js/app.js
RUN test -f resources/js/client.js
RUN test -f resources/sass/app.scss

RUN npm run build

RUN test -d public/build
RUN test -f public/build/manifest.json
RUN test ! -f public/hot

# ============================================================
# STAGE 2: PHP DEPENDENCIES
# ============================================================

FROM composer:2 AS composer

WORKDIR /var/www/html

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts


# ============================================================
# STAGE 3: PRODUCTION
# ============================================================

FROM php:8.3-fpm-alpine

WORKDIR /var/www/html

# ------------------------------------------------------------
# System packages
# ------------------------------------------------------------

RUN apk add --no-cache \
    nginx \
    supervisor \
    icu-dev \
    oniguruma-dev \
    libzip-dev \
    zip \
    unzip \
    curl \
    bash

# ------------------------------------------------------------
# PHP extensions
# ------------------------------------------------------------

RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    mbstring \
    intl \
    bcmath \
    opcache \
    zip

# ------------------------------------------------------------
# Laravel application
# ------------------------------------------------------------

COPY . .

# ------------------------------------------------------------
# Composer dependencies
# ------------------------------------------------------------

COPY --from=composer \
    /var/www/html/vendor \
    /var/www/html/vendor

# ------------------------------------------------------------
# Vite production assets
# ------------------------------------------------------------

COPY --from=frontend \
    /var/www/html/public/build \
    /var/www/html/public/build

# ------------------------------------------------------------
# Remove development hot file
# ------------------------------------------------------------

RUN rm -f public/hot

# ------------------------------------------------------------
# Permissions
# ------------------------------------------------------------

RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache

RUN chmod -R ug+rwX \
    storage \
    bootstrap/cache

# ------------------------------------------------------------
# Nginx
# ------------------------------------------------------------

COPY docker/nginx/default.conf \
    /etc/nginx/http.d/default.conf

# ------------------------------------------------------------
# PHP-FPM environment
# ------------------------------------------------------------

RUN cat > /usr/local/etc/php-fpm.d/99-environment.conf <<'EOF'
[www]

clear_env = no

catch_workers_output = yes

decorate_workers_output = no
EOF

# ------------------------------------------------------------
# Supervisor
# ------------------------------------------------------------

COPY docker/supervisord.conf \
    /etc/supervisord.conf

# ------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------

COPY docker/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# ------------------------------------------------------------
# Expose HTTP
# ------------------------------------------------------------

EXPOSE 80

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
