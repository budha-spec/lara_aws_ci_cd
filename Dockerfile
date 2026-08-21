# ============================================================
# Stage 1: Frontend - Vite
# ============================================================
FROM node:22-alpine AS frontend

WORKDIR /app

# Install Node dependencies first for Docker layer caching
COPY package.json package-lock.json ./

RUN npm ci

# Copy files required by Vite
COPY resources ./resources
COPY public ./public
COPY vite.config.js ./

# Build production Vite assets
RUN npm run build


# ============================================================
# Stage 2: Laravel + PHP-FPM + Nginx
# ============================================================
FROM php:8.3-fpm

WORKDIR /var/www/html

# ------------------------------------------------------------
# System packages
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    unzip \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libonig-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        bcmath \
        gd \
        zip \
        intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ------------------------------------------------------------
# Composer
# ------------------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer


# ------------------------------------------------------------
# Laravel dependencies
# ------------------------------------------------------------
COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader


# ------------------------------------------------------------
# Laravel application
# ------------------------------------------------------------
COPY . .


# ------------------------------------------------------------
# Copy Vite production assets
# ------------------------------------------------------------
COPY --from=frontend /app/public/build ./public/build


# ------------------------------------------------------------
# Laravel permissions
# ------------------------------------------------------------
RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache


# ------------------------------------------------------------
# Laravel optimization
# ------------------------------------------------------------
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache


# ------------------------------------------------------------
# Nginx
# ------------------------------------------------------------
COPY docker/nginx/default.conf \
    /etc/nginx/sites-available/default


# ------------------------------------------------------------
# Supervisor
# ------------------------------------------------------------
COPY docker/supervisor/supervisord.conf \
    /etc/supervisor/conf.d/supervisord.conf


# ------------------------------------------------------------
# Expose HTTP
# ------------------------------------------------------------
EXPOSE 80


# ------------------------------------------------------------
# Start Supervisor
# ------------------------------------------------------------
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]