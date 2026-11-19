# PHP 8.6 Starter

PHP **8.6.0** on Railway: compiled from the official php.net source,
served by nginx + php-fpm as a non-root user, with a health endpoint
that tells the truth.

## Why this exists

PHP 8.6.0 was released on 19 November 2026. On release day there was
no other PHP 8.6 template on Railway, and Docker Hub's official `php`
image had not published final 8.6.0 tags yet — so this starter does
not wait for either. Its Dockerfile downloads the official
`php-8.6.0.tar.xz` from php.net, verifies the sha256 php.net
publishes for it, and compiles exactly that release.

When the official `php:8.6.x-fpm-alpine` image lands, the build stage
will be swapped for it. The application, nginx configuration, and
entrypoint stay the same.

## What you get

- PHP 8.6.0 (FPM) with OPcache built in and tuned
- Extensions: pdo_pgsql, pdo_sqlite, intl, mbstring, zip, bcmath,
  pcntl, sockets, curl, openssl, sodium
- nginx in front, php-fpm behind it, only `public/index.php` ever
  executes — no mod_php, no other `.php` file reachable
- Runs as `www-data` (non-root); hardened `php.ini` settings,
  including `session.upload_progress` disabled
- Composer 2.9 in the image for your own dependencies
- A dependency-free demo app: a status page plus two JSON endpoints

## Endpoints

| Path | What it does |
| --- | --- |
| `/` | Status page showing the running PHP version |
| `/api/health` | `{"status", "php", "opcache", "database"}` — the Railway healthcheck target |
| `/api/info` | PHP 8.6 feature probes (clamp(), Time\Duration, SortDirection, Io\Poll) and loaded extensions, all checked against the real runtime |

`/api/health` reports the database honestly: `not_configured` when
no `DATABASE_URL` is set, `ok` only after a real query succeeds, and
`error` with HTTP 503 when a configured database does not answer.

## Using it

1. Deploy the template. No variables are required.
2. Optional: add a Postgres service and set
   `DATABASE_URL=${{Postgres.DATABASE_URL}}` on the app service.
3. Replace `public/index.php` with your own application.

## Trade-offs, stated plainly

- **First deploys build PHP from source** and take several minutes
  longer than an image pull. That is the cost of shipping on release
  day; it disappears when the template swaps to the official image.
- The demo app is a starting point, not a framework. For Laravel,
  see the Laravel AI SDK Starter template instead.

## Verification

- Source tarball sha256 verified against php.net's downloads page.
- PHP 8.6.0 compiled from this source locally and the demo endpoints
  exercised against the compiled runtime before publishing.
- Live Railway deploy: see the template page for the current status;
  this README is updated when a live deploy has been verified.
