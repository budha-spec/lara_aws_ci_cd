# ============================================================
# STAGE 1: VITE / FRONTEND BUILD
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
# Production Vite build
# ------------------------------------------------------------

ENV NODE_ENV=production

RUN rm -f /app/public/hot

RUN npm run build

# ------------------------------------------------------------
# Verify Vite output
# ------------------------------------------------------------

RUN echo "======================================"
RUN echo "VITE BUILD OUTPUT"
RUN echo "======================================"

RUN find /app/public/build \
    -maxdepth 4 \
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
# STAGE 2: PHP + NGINX
# ============================================================

FROM php:8.3-fpm

WORKDIR /var/www/html

# ============================================================
# SYSTEM PACKAGES
# ============================================================

RUN apt-get update \
    && apt-get install -y \
        nginx \
        supervisor \
        git \
        unzip \
        curl \
        bash \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libicu-dev \
        libonig-dev \
        libpq-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo \
        pdo_mysql \
        pdo_pgsql \
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
# PHP-FPM
# ============================================================

RUN sed -i \
    's/^;clear_env = no/clear_env = no/' \
    /usr/local/etc/php-fpm.d/www.conf \
    || true

RUN sed -i \
    's/^clear_env = yes/clear_env = no/' \
    /usr/local/etc/php-fpm.d/www.conf \
    || true

RUN sed -i \
    's|^listen = 9000|listen = 127.0.0.1:9000|' \
    /usr/local/etc/php-fpm.d/www.conf


# ============================================================
# PHP-FPM ENVIRONMENT
#
# Environment variables are supplied at RUNTIME by
# Elastic Beanstalk / Docker.
#
# DO NOT put secrets into the Docker image.
# ============================================================

RUN cat > /usr/local/etc/php-fpm.d/99-environment.conf <<'EOF'
[www]

clear_env = no

env[APP_ENV] = $APP_ENV
env[APP_DEBUG] = $APP_DEBUG
env[APP_KEY] = $APP_KEY
env[APP_URL] = $APP_URL

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
    # Security
    # --------------------------------------------------------

    location ~ /\.(?!well-known).* {
        deny all;
    }

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
# COMPOSER
# ============================================================

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./


# ============================================================
# LARAVEL APPLICATION
# ============================================================

COPY . .


# ============================================================
# REMOVE EXTERNAL CONFIG CACHE
# ============================================================

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
# COPY VITE PRODUCTION BUILD
# ============================================================

COPY --from=frontend \
    /app/public/build \
    /var/www/html/public/build


# ============================================================
# NEVER SHIP VITE HOT FILE
# ============================================================

RUN rm -f /var/www/html/public/hot


# ============================================================
# REMOVE NODE / BUILD FILES
# ============================================================

RUN rm -rf \
    /var/www/html/node_modules \
    /root/.npm \
    /tmp/*


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
    /var/www/html/bootstrap/cache \
    /var/www/html/public

RUN chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache


# ============================================================
# LARAVEL OPTIMIZATION
#
# No config:cache here because runtime environment variables
# are supplied by Elastic Beanstalk.
# ============================================================

RUN php artisan optimize:clear


# ============================================================
# FINAL VITE VALIDATION
# ============================================================

RUN test -d /var/www/html/public/build

RUN test -f /var/www/html/public/build/manifest.json

RUN test ! -f /var/www/html/public/hot


# ============================================================
# NGINX VALIDATION
# ============================================================

RUN nginx -t


# ============================================================
# ENTRYPOINT
# ============================================================

COPY docker/entrypoint.sh \
    /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh


# ============================================================
# PORT
# ============================================================

EXPOSE 80


# ============================================================
# START
# ============================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
