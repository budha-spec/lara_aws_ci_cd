# ============================================================
# STAGE 1: VITE / FRONTEND BUILD
# ============================================================

FROM node:22-alpine AS frontend

WORKDIR /var/www/html

COPY package.json package-lock.json* ./

RUN if [ -f package-lock.json ]; then \
        npm ci; \
    else \
        npm install; \
    fi

COPY . .

# Never use Vite HMR in production
RUN rm -f public/hot

RUN echo "======================================"
RUN echo "NODE VERSION"
RUN node --version

RUN echo "======================================"
RUN echo "NPM VERSION"
RUN npm --version

RUN echo "======================================"
RUN echo "PACKAGE.JSON"
RUN cat package.json

RUN echo "======================================"
RUN echo "VITE CONFIG"
RUN cat vite.config.js

RUN echo "======================================"
RUN echo "RUNNING VITE BUILD"
RUN echo "======================================"

RUN npm run build -- --debug

# Diagnostics
RUN echo "======================================"
RUN echo "VITE BUILD RESULT"
RUN echo "======================================"

RUN find public/build \
    -maxdepth 3 \
    -type f \
    -print \
    | sort

# Required for Laravel Vite
RUN test -d public/build

RUN test -f public/build/manifest.json

# Must never exist in production
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
    curl \
    bash \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    postgresql-dev \
    mysql-client \
    mariadb-connector-c-dev \
    unzip \
    git \
    tzdata

# ============================================================
# PHP EXTENSIONS
# ============================================================

RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
        bcmath \
        intl \
        zip \
        opcache \
        gd

# ============================================================
# PHP PRODUCTION CONFIGURATION
# ============================================================

RUN mv "$PHP_INI_DIR/php.ini-production" \
       "$PHP_INI_DIR/php.ini"

# ============================================================
# PHP-FPM CONFIGURATION
# ============================================================

RUN sed -i 's|^;clear_env = no|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf \
    || true

RUN sed -i 's|^clear_env = yes|clear_env = no|' \
    /usr/local/etc/php-fpm.d/www.conf \
    || true

RUN sed -i 's|^listen = 9000|listen = 127.0.0.1:9000|' \
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
# This allows PHP-FPM workers to see environment variables.
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

RUN rm -f /etc/nginx/http.d/default.conf

RUN cat > /etc/nginx/http.d/default.conf <<'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name _;

    root /var/www/html/public;

    index index.php index.html;

    # --------------------------------------------------------
    # Laravel / application
    # --------------------------------------------------------

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # --------------------------------------------------------
    # Vite / static assets
    #
    # These must be served directly by Nginx.
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

# ============================================================
# SUPERVISOR
# ============================================================

RUN mkdir -p /etc/supervisor.d

RUN cat > /etc/supervisord.conf <<'EOF'
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
# COPY COMPOSER DEPENDENCIES
# ============================================================

COPY --from=composer \
    /var/www/html/vendor \
    /var/www/html/vendor

# ============================================================
# COPY APPLICATION
# ============================================================

COPY . /var/www/html

# ============================================================
# COPY VITE PRODUCTION BUILD
# ============================================================

COPY --from=frontend \
    /var/www/html/public/build \
    /var/www/html/public/build

# ============================================================
# IMPORTANT:
#
# Never ship Vite's development hot file.
# ============================================================

RUN rm -f /var/www/html/public/hot

# ============================================================
# REMOVE NODE / DEVELOPMENT FILES FROM RUNTIME IMAGE
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
# Do NOT run config:cache here unless all production
# environment variables are available during docker build.
# ============================================================

RUN php artisan optimize:clear

# ============================================================
# FINAL VITE VALIDATION
# ============================================================

RUN test -d /var/www/html/public/build

RUN test -f /var/www/html/public/build/manifest.json

RUN test ! -f /var/www/html/public/hot

# ============================================================
# ENTRYPOINT
# ============================================================

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# ============================================================
# PORT
# ============================================================

EXPOSE 80

# ============================================================
# START
# ============================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
