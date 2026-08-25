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

# Verify Vite output
RUN echo "======================================" \
    && echo "VITE BUILD OUTPUT" \
    && echo "======================================" \
    && find /app/public/build -maxdepth 2 -type f -print


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


# ============================================================
# COMPOSER
# ============================================================

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./


# ============================================================
# LARAVEL APPLICATION
# ============================================================

COPY . .


# Never use a config cache generated outside container
RUN rm -f bootstrap/cache/config.php


# ============================================================
# PHP DEPENDENCIES
# ============================================================

RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction \
    --no-progress


# ============================================================
# VITE BUILD
# ============================================================

COPY --from=frontend /app/public/build ./public/build


# Verify Vite assets inside final image
RUN echo "======================================" \
    && echo "FINAL IMAGE VITE BUILD" \
    && echo "======================================" \
    && find /var/www/html/public/build -maxdepth 2 -type f -print \
    && test -f /var/www/html/public/build/manifest.json


# ============================================================
# LARAVEL PERMISSIONS
# ============================================================

RUN chown -R www-data:www-data \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache \
    && chmod -R 775 \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache


# ============================================================
# NGINX
# ============================================================

RUN rm -f /etc/nginx/sites-enabled/default

COPY docker/nginx/default.conf \
    /etc/nginx/sites-available/default

RUN ln -sf \
    /etc/nginx/sites-available/default \
    /etc/nginx/sites-enabled/default


# ============================================================
# PHP-FPM ENVIRONMENT
# ============================================================

COPY docker/php/99-environment.conf \
    /usr/local/etc/php-fpm.d/99-environment.conf


# ============================================================
# SUPERVISOR
# ============================================================

COPY docker/supervisor/supervisord.conf \
    /etc/supervisor/conf.d/supervisord.conf


# ============================================================
# ENTRYPOINT
# ============================================================

COPY docker/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh


# ============================================================
# VALIDATE NGINX
# ============================================================

RUN nginx -t


EXPOSE 80


ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
