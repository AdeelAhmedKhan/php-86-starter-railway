# syntax=docker/dockerfile:1
# PHP 8.6 starter — PHP 8.6.0 compiled from the official php.net source.
#
# WHY FROM SOURCE (and not the official Docker image): PHP 8.6.0 went
# GA on 2026-11-19, but Docker Hub's official `php` image had no final
# 8.6.0 tags yet (only 8.6.0RC7 pre-releases). Rather than wait, this
# Dockerfile compiles the official php.net release tarball, pinned by
# version AND by the sha256 php.net publishes for it. When the
# official `php:8.6.x-fpm-alpine` image lands, this file will be
# swapped to it; the app, nginx, and entrypoint layers do not change.
#
# WHY php-fpm + nginx (and NEVER mod_php): the October 2026 php2shell
# RCEs (CVE-2026-109618 / CVE-2026-109619, CVSS v4.0 9.2) are
# unauthenticated remote code execution in PHP itself; mod_php runs
# the interpreter inside the web server process. php-fpm keeps PHP in
# a separate process behind nginx, which only ever forwards requests
# to `public/index.php`.
#
# OPcache needs no install step: since PHP 8.5 it is built into the
# binary, so there is no shared module. The settings in
# docker/php/opcache.ini apply to the built-in extension.

# ------------------------------------------------------------------
# Stage 1 — build PHP 8.6.0 from the official source tarball.
# ------------------------------------------------------------------
FROM alpine:3.22 AS phpbuild

ARG PHP_VERSION=8.6.0
ARG PHP_SHA256=5f84beaa3d763aee1e4feed99bf54ec692c383b322e25626807b589238c3a087

RUN apk add --no-cache \
        build-base autoconf pkgconf bison re2c \
        curl xz \
        libxml2-dev openssl-dev sqlite-dev postgresql-dev \
        icu-dev libzip-dev oniguruma-dev curl-dev libsodium-dev \
        zlib-dev

WORKDIR /usr/src
RUN curl -fsSL -o php.tar.xz "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz" \
    && echo "${PHP_SHA256}  php.tar.xz" | sha256sum -c - \
    && mkdir -p php-src \
    && tar -xf php.tar.xz -C php-src --strip-components=1 \
    && rm php.tar.xz

WORKDIR /usr/src/php-src
RUN ./configure \
        --prefix=/usr/local \
        --with-config-file-path=/usr/local/etc/php \
        --with-config-file-scan-dir=/usr/local/etc/php/conf.d \
        --enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data \
        --disable-cgi \
        --enable-mbstring \
        --enable-intl \
        --enable-bcmath \
        --enable-pcntl \
        --enable-sockets \
        --with-pdo-pgsql \
        --with-pdo-sqlite \
        --with-sqlite3 \
        --with-openssl \
        --with-curl \
        --with-zip \
        --with-zlib \
        --with-sodium \
    && make -j"$(nproc)" \
    && make install \
    && cp php.ini-production /usr/local/etc/php/php.ini \
    && strip /usr/local/bin/php /usr/local/sbin/php-fpm || true

# Fail the BUILD, not the deploy, if FPM did not install where the
# runtime stage and entrypoint expect it (live test 2: the deploy
# crashed with "php-fpm: not found" and no build-side evidence).
RUN test -x /usr/local/sbin/php-fpm && /usr/local/bin/php -v | head -1

# ------------------------------------------------------------------
# Stage 2 — runtime: the compiled PHP + nginx. No compilers, no
# source, no build tools in the final image. Runs as non-root.
# ------------------------------------------------------------------
FROM alpine:3.22 AS runtime

# Runtime libraries only — the matching -dev packages stay behind in
# the build stage.
RUN apk add --no-cache \
        nginx \
        libxml2 openssl sqlite-libs libpq icu-libs libzip \
        oniguruma libcurl libsodium zlib ca-certificates \
    && rm -rf /var/cache/apk/*

# The www-data user the official php images use (uid/gid 82). Alpine's
# base image already ships www-data with those ids, so create only
# what is missing — the first live Railway build failed with
# "addgroup: group 'www-data' in use" on the unguarded version.
RUN (grep -q '^www-data:' /etc/group || addgroup -S -g 82 www-data) \
    && (grep -q '^www-data:' /etc/passwd || adduser -S -u 82 -G www-data www-data)

COPY --from=phpbuild /usr/local /usr/local
COPY --from=composer:2.9.8 /usr/bin/composer /usr/bin/composer

# Same assertion on the runtime side of the COPY.
RUN test -x /usr/local/sbin/php-fpm

# php-fpm: main config (global) + pool, both provided by this starter
# because a source build ships neither in usable form.
COPY docker/php/php-fpm-main.conf /usr/local/etc/php-fpm.conf
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/zz-app.conf

# PHP hardening: see docker/php/security.ini for what each line does.
COPY docker/php/security.ini /usr/local/etc/php/conf.d/99-security.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

# nginx: template with ${PORT} substituted at container start.
COPY docker/nginx.conf /etc/nginx/nginx.conf.template

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app
COPY --chown=www-data:www-data public ./public

# Writable dirs for a non-root runtime user. /run/nginx holds the
# rendered nginx config and both pid files (see entrypoint.sh).
RUN mkdir -p /var/log/nginx /var/lib/nginx \
        /var/lib/nginx/tmp/client_body /var/lib/nginx/tmp/proxy \
        /var/lib/nginx/tmp/fastcgi /var/lib/nginx/tmp/uwsgi \
        /var/lib/nginx/tmp/scgi /run/nginx \
    && chown -R www-data:www-data /var/log/nginx /var/lib/nginx /run/nginx

USER www-data
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
