# ============================================================
# FRONTEND BUILD
# ============================================================

FROM node:22 AS frontend

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY resources ./resources
COPY public ./public
COPY vite.config.js ./

RUN npm run build


# ============================================================
# PHP + NGINX
# ============================================================

FROM php:8.3-fpm

WORKDIR /var/www/html

RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libonig-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        mbstring \
        bcmath \
        gd \
        zip \
        intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy Composer files first
COPY composer.json composer.lock ./

# Copy Laravel application
COPY . .

# Install PHP dependencies
RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# Copy Vite build
COPY --from=frontend /app/public/build ./public/build

# Laravel permissions
RUN chown -R www-data:www-data \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache \
    && chmod -R 775 \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache

# Verify Laravel public directory
RUN echo "=== PUBLIC DIRECTORY ===" \
    && ls -la /var/www/html/public \
    && echo "=== INDEX.PHP ===" \
    && ls -la /var/www/html/public/index.php

# Nginx
RUN rm -f /etc/nginx/sites-enabled/default

COPY docker/nginx/default.conf \
    /etc/nginx/sites-available/default

RUN ln -sf \
    /etc/nginx/sites-available/default \
    /etc/nginx/sites-enabled/default

# Supervisor
COPY docker/supervisor/supervisord.conf \
    /etc/supervisor/conf.d/supervisord.conf

# Validate Nginx configuration
RUN nginx -t

EXPOSE 80

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]