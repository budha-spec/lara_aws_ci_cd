# ============================================================
# STAGE 1: VITE / FRONTEND BUILD
# ============================================================

FROM node:22-alpine AS frontend

WORKDIR /app

# ------------------------------------------------------------
# NPM dependencies
# ------------------------------------------------------------

COPY package.json package-lock.json ./

RUN npm ci

# ------------------------------------------------------------
# Frontend source
# ------------------------------------------------------------

COPY resources ./resources
COPY public ./public
COPY vite.config.js ./

# ------------------------------------------------------------
# Never use Vite HMR in production
# ------------------------------------------------------------

RUN rm -f public/hot

# ------------------------------------------------------------
# Production build
# ------------------------------------------------------------

ENV NODE_ENV=production

RUN npm run build

# ------------------------------------------------------------
# Verify Vite build
# ------------------------------------------------------------

RUN echo "======================================"
RUN echo "VITE BUILD OUTPUT"
RUN echo "======================================"

RUN find /app/public/build \
    -maxdepth 3 \
    -type f \
    -print \
    | sort

RUN test -d /app/public/build
RUN test -f /app/public/build/manifest.json
RUN test ! -f /app/public/hot

RUN echo "Vite build: OK"
RUN echo "Vite manifest: OK"
RUN echo "Vite hot file: NOT PRESENT"


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
# Production dependencies
# ------------------------------------------------------------

RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction \
    --no-progress \
    --no-scripts


# ============================================================
# STAGE 3: PRODUCTION APPLICATION
# ============================================================

FROM php:8.3-fpm

WORKDIR /var/www/html

# ============================================================
# SYSTEM PACKAGES
# ============================================================

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
    && docker-php-ext-install -j"$(nproc)" \
        pdo \
        pdo_mysql \
        mbstring \
        bcmath \
        gd \
        zip \
        intl \
        opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# PHP PRODUCTION CONFIGURATION
# ============================================================

RUN mv "$PHP_INI_DIR/php.ini-production" \
       "$PHP_INI_DIR/php.ini"


# ============================================================
# PHP-FPM CONFIGURATION
# ============================================================

RUN sed -i \
    's/^;clear_env = no/clear_env = no/' \
    /usr/local/etc/php-fpm.d/www.conf

RUN sed -i \
    's/^clear_env = yes/clear_env = no/' \
    /usr/local/etc/php-fpm.d/www.conf

RUN sed -i \
    's|^listen = 9000|listen = 127.0.0.1:9000|' \
    /usr/local/etc/php-fpm.d/www.conf


# ============================================================
# PHP OPCACHE
# ============================================================

RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=20000'; \
        echo 'opcache.revalidate_freq=0'; \
    } > /usr/local/etc/php/conf.d/opcache.ini


# ============================================================
# PHP-FPM ENVIRONMENT
#
# Important:
# PHP-FPM workers inherit Docker environment variables.
# ============================================================

RUN cat > /usr/local/etc/php-fpm.d/99-environment.conf <<'EOF'
[www]

clear_env = no
EOF


# ============================================================
# NGINX DIRECTORIES
# ============================================================

RUN mkdir -p \
    /run/nginx \
    /var/log/nginx \
    /var/cache/nginx


# ============================================================
# NGINX CONFIGURATION
# ============================================================

RUN rm -f /etc/nginx/sites-enabled/default

RUN cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name _;

    root /var/www/html/public;

    index index.php index.html;

    # --------------------------------------------------------
    # Laravel
    # --------------------------------------------------------

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # --------------------------------------------------------
    # Vite production assets
    # --------------------------------------------------------

    location ^~ /build/ {
        try_files $uri =404;

        access_log off;

        expires 1y;

        add_header Cache-Control "public, immutable";
    }

    # --------------------------------------------------------
    # Static files
    # --------------------------------------------------------

    location ~* \.(?:css|js|mjs|map|png|jpg|jpeg|gif|svg|ico|webp|avif|woff|woff2|ttf|otf)$ {
        try_files $uri =404;

        access_log off;

        expires 1y;

        add_header Cache-Control "public, immutable";
    }

    # --------------------------------------------------------
    # PHP
    # --------------------------------------------------------

    location ~ \.php$ {
        try_files $uri =404;

        include fastcgi_params;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;

        fastcgi_pass 127.0.0.1:9000;

        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    # --------------------------------------------------------
    # Hidden files
    # --------------------------------------------------------

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # --------------------------------------------------------
    # Sensitive files
    # --------------------------------------------------------

    location ~* /(composer\.(json|lock)|package(-lock)?\.json|vite\.config\.(js|ts)|\.env) {
        deny all;
    }
}
EOF

RUN ln -sf \
    /etc/nginx/sites-available/default \
    /etc/nginx/sites-enabled/default


# ============================================================
# SUPERVISOR
# ============================================================

RUN mkdir -p /etc/supervisor/conf.d

RUN cat > /etc/supervisor/conf.d/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/dev/null
logfile_maxbytes=0
pidfile=/run/supervisord.pid

[program:php-fpm]
command=/usr/local/sbin/php-fpm --nodaemonize
priority=10
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
priority=20
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF


# ============================================================
# COPY LARAVEL APPLICATION
# ============================================================

COPY . /var/www/html


# ============================================================
# COPY COMPOSER DEPENDENCIES
# ============================================================

COPY --from=composer \
    /app/vendor \
    /var/www/html/vendor


# ============================================================
# COPY VITE BUILD
# ============================================================

COPY --from=frontend \
    /app/public/build \
    /var/www/html/public/build


# ============================================================
# REMOVE VITE HOT FILE
# ============================================================

RUN rm -f /var/www/html/public/hot


# ============================================================
# REMOVE DEVELOPMENT FILES
# ============================================================

RUN rm -rf \
    /var/www/html/node_modules \
    /var/www/html/.npm \
    /root/.npm \
    /tmp/*


# ============================================================
# REMOVE BUILD-TIME LARAVEL CONFIG CACHE
#
# Runtime environment variables are NOT available during
# Docker build.
# ============================================================

RUN rm -f \
    /var/www/html/bootstrap/cache/config.php


# ============================================================
# LARAVEL DIRECTORIES
# ============================================================

RUN mkdir -p \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache


# ============================================================
# PERMISSIONS
# ============================================================

RUN chown -R www-data:www-data \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache

RUN chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache


# ============================================================
# CLEAR BUILD-TIME LARAVEL CACHE
# ============================================================
#
# This does NOT require APP_KEY.
# It only removes generated cache files.
# ============================================================

RUN php artisan optimize:clear


# ============================================================
# FINAL VITE VALIDATION
# ============================================================

RUN echo "======================================"
RUN echo "FINAL VITE VALIDATION"
RUN echo "======================================"

RUN test -d /var/www/html/public/build

RUN test -f /var/www/html/public/build/manifest.json

RUN test ! -f /var/www/html/public/hot

RUN echo "Vite production assets: OK"
RUN echo "Vite manifest: OK"
RUN echo "Vite hot file: NOT PRESENT"


# ============================================================
# ENTRYPOINT
# ============================================================

COPY docker/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x \
    /usr/local/bin/entrypoint.sh


# ============================================================
# NGINX VALIDATION
# ============================================================

RUN nginx -t


# ============================================================
# PORT
# ============================================================

EXPOSE 80


# ============================================================
# START
# ============================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
