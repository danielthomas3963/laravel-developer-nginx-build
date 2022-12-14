# syntax=docker/dockerfile:1

ARG platform=linux/amd64
FROM --platform=$platform php:8-fpm-alpine

LABEL org.opencontainers.image.authors="Luciano Mammino"
LABEL org.opencontainers.image.url="https://github.com/lmammino/laravel-nginx"
LABEL org.opencontainers.image.documentation="https://github.com/lmammino/laravel-nginx"
LABEL org.opencontainers.image.source="https://github.com/lmammino/laravel-nginx"
LABEL org.opencontainers.image.licenses="MIT"

# Install base dependencies
RUN apk --update add --no-cache bash icu-dev nginx supervisor nodejs npm yarn

# Configure php
RUN docker-php-ext-install pdo pdo_mysql mysqli sockets opcache \
  && docker-php-ext-configure intl \
  && docker-php-ext-install intl
RUN { \
  echo 'opcache.memory_consumption=128'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=4000'; \
  echo 'opcache.revalidate_freq=2'; \
  echo 'opcache.fast_shutdown=1'; \
  echo 'opcache.enable_cli=1'; \
  } > /usr/local/etc/php/conf.d/php-opocache-cfg.ini

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configure supervisor
RUN mkdir -p /etc/supervisor.d/
COPY ./config/supervisord.ini /etc/supervisor.d/supervisord.ini

# Configure php-fpm
RUN mkdir -p /run/php/ && touch /run/php/php8.0-fpm.pid && touch /run/php/php8.0-fpm.sock
COPY ./config/php-fpm.conf ./config/php.ini /usr/local/etc/php/

WORKDIR /app

# Configure nginx
COPY ./config/nginx.conf ./config/fastcgi-php.conf /etc/nginx/
RUN mkdir -p /run/nginx/ \
  && touch /run/nginx/nginx.pid \
  && chown -R www-data:www-data /app/ /tmp/ /var/ /run/

# Copy php sources (will be replaced with a volume if in dev mode)
COPY --chown=www-data ./config/index.php /app/public/index.php

# Copy start script
COPY ./config/*.sh /usr/bin/
RUN chmod +x /usr/bin/start.sh /usr/bin/nginx-healthcheck.sh

EXPOSE 80
CMD start.sh
USER www-data

HEALTHCHECK CMD ["nginx-healthcheck.sh"]
