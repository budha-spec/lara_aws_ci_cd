# ============================================================
# VITE BUILD
# ============================================================

FROM node:22-alpine AS frontend

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY resources ./resources
COPY public ./public
COPY vite.config.js ./

RUN npm run build \
    && test -f public/build/manifest.json


# ============================================================
# COMPOSER DEPENDENCIES
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
# APPLICATION
# ============================================================

FROM php:8.3-fpm-alpine

WORKDIR /var/www/html


# ============================================================
# RUNTIME PACKAGES
# ============================================================

RUN apk add --no-cache \
    nginx \
    supervisor \
    bash \
    tzdata \
    libpng \
    libjpeg-turbo \
    freetype \
    icu-libs \
    libzip \
    oniguruma


# ============================================================
# PHP EXTENSIONS
# ============================================================

RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
  && docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" \
    pdo_mysql \
    mbstring \
    bcmath \
    gd \
    intl \
    zip \
    opcache \
  && apk del .build-deps \
  && rm -rf /tmp/*


# ============================================================
# PHP CONFIGURATION
# ============================================================

RUN mv \
    "$PHP_INI_DIR/php.ini-production" \
    "$PHP_INI_DIR/php.ini"

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
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
EOF


# ============================================================
# PHP-FPM
# ============================================================

RUN sed -i \
    -e 's|^listen = 9000|listen = 127.0.0.1:9000|' \
    -e 's|^;clear_env = no|clear_env = no|' \
    -e 's|^clear_env = yes|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf


# ============================================================
# NGINX
# ============================================================

RUN mkdir -p \
    /run/nginx \
    /var/cache/nginx \
    /var/log/nginx

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

COPY --from=composer \
    /app/vendor \
    /var/www/html/vendor

COPY --from=frontend \
    /app/public/build \
    /var/www/html/public/build


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
    public \
  && chmod -R 775 \
    storage \
    bootstrap/cache


# ============================================================
# ENTRYPOINT
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


EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
