#!/bin/sh
# Entrypoint for the PHP 8.6 starter container.
# - Substitutes $PORT into the nginx config (Railway injects $PORT).
# - Starts php-fpm in the background and nginx in the foreground.
set -eu

PORT="${PORT:-8080}"
export PORT

# Render nginx config from the template.
# (envsubst is not in the Alpine image; use sed on the one variable.)
# The rendered file goes to /run/nginx, NOT /etc/nginx: the container
# runs as www-data and /etc/nginx is root-owned and read-only to it.
# /run/nginx is created and chowned to www-data in the Dockerfile.
sed "s|\${PORT}|${PORT}|g" /etc/nginx/nginx.conf.template > /run/nginx/nginx.conf

# php-fpm in the background, nginx in the foreground (PID 1).
# -c points nginx at the config rendered into /run/nginx above; its
# relative includes (fastcgi_params) still resolve against the
# compiled prefix /etc/nginx, and mime.types is included by absolute
# path, so nothing else moves.
# php-fpm is called by ABSOLUTE path: live test 2 failed with
# "php-fpm: not found" on the bare name, so PATH is not trusted here.
# The echo lines stay in the log as evidence of what the image holds.
/usr/local/sbin/php-fpm -D
exec nginx -c /run/nginx/nginx.conf -g 'daemon off;'
