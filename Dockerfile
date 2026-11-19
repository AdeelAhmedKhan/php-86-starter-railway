# syntax=docker/dockerfile:1
# PHP 8.6 starter — the official php:8.6.0-fpm-alpine image, pinned by
# tag AND digest, with nginx in front and php-fpm behind it.
#
# HISTORY: this starter first shipped on 2026-11-19 compiling PHP
# 8.6.0 from the official php.net tarball, because Docker Hub had no
# final 8.6.0 tags on release day (only 8.6.0RC7). The official tags
# landed the same day, so the from-source stage was retired: builds
# drop from minutes of compiling to an image pull, and patch
# releases (8.6.1, 8.6.2, ...) become a one-line tag + digest bump
# in this file. The sha256 below is the amd64 image digest Docker
# Hub publishes for the tag; verify it there before every bump.
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

FROM php:8.6.0-fpm-alpine@sha256:001767ab28523ebf2ff679d6529610be4cccb444e39ff5e0a71c5581636e7c73

# Extensions the source build compiled in, now installed the
# official-image way. Runtime libraries stay; the -dev packages and
# build tools are removed in the same layer. linux-headers is
# included because ext/sockets needs kernel headers to compile on
# Alpine (that omission once sank the from-source build).
# The sqlite3 extension is deliberately NOT in the list: its PHP
# 8.6 source ships config0.m4 instead of config.m4 and
# docker-php-ext-install fails on it (live test 5, 2026-11-20).
# pdo_sqlite is the SQLite access this starter promises.
RUN apk add --no-cache --virtual .runtime-libs \
        nginx icu-libs libpq sqlite-libs libzip oniguruma libcurl libsodium ca-certificates \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS linux-headers icu-dev postgresql-dev sqlite-dev libzip-dev oniguruma-dev curl-dev \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql pdo_sqlite intl mbstring zip bcmath pcntl sockets curl \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Fail the BUILD, not the deploy, if the runtime is not exactly
# what this starter promises: php-fpm present, PHP 8.6.0, and every
# extension the README lists actually loaded. OPcache is checked
# under the name php -m actually prints, "Zend OPcache" — the
# plain name failed live test 6 while OPcache was built in all
# along.
RUN test -x /usr/local/sbin/php-fpm \
    && php -v | head -1 | grep -q 'PHP 8.6.0' \
    && for ext in pdo_pgsql pdo_sqlite intl mbstring zip bcmath pcntl sockets curl openssl sodium zlib; do \
        php -m | grep -qi "^${ext}$" || { echo "missing extension: ${ext}"; exit 1; }; \
    done \
    && php -m | grep -q '^Zend OPcache$'

COPY --from=composer:2.9.8 /usr/bin/composer /usr/bin/composer

# Production php.ini as the base; the image ships it in PHP_INI_DIR.
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# php-fpm: this starter's own main config + pool. The image's
# shipped pool files are removed first — its www.conf would define
# a second [www] pool and collide with ours.
RUN rm -f /usr/local/etc/php-fpm.d/*.conf
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

# Writable dirs for the non-root runtime user. /run/nginx holds the
# rendered nginx config and both pid files (see entrypoint.sh).
RUN mkdir -p /var/log/nginx /var/lib/nginx \
        /var/lib/nginx/tmp/client_body /var/lib/nginx/tmp/proxy \
        /var/lib/nginx/tmp/fastcgi /var/lib/nginx/tmp/uwsgi \
        /var/lib/nginx/tmp/scgi /run/nginx \
    && chown -R www-data:www-data /var/log/nginx /var/lib/nginx /run/nginx

USER www-data
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
