# PHP 8.6 Starter

PHP **8.6.0** on Railway: the official `php:8.6.0-fpm-alpine`
image, pinned by tag and digest, served by nginx + php-fpm as a
non-root user, with a health endpoint that tells the truth.

## Why this exists

PHP 8.6.0 was released on 19 November 2026, and on release day
there was no other PHP 8.6 template on Railway. This starter
shipped the same day, at first compiling PHP from the official
php.net source because Docker Hub had not published final 8.6.0
tags yet. Those tags have since landed, so the build now uses
the official image, pinned by tag and digest: deploys take an
image pull instead of a source compile, and patch releases
become a one-line bump in the Dockerfile.

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

- The image is pinned to PHP 8.6.0 by digest, so patch releases
  (8.6.1 and later) arrive only when the pin is bumped in the
  Dockerfile. That is deliberate: a redeploy never changes your
  PHP version silently. Watch the repo if you want the bumps.
- The demo app is a starting point, not a framework. For Laravel,
  see the Laravel AI SDK Starter template instead.

## Verification

- The image digest in the Dockerfile is the amd64 digest Docker
  Hub publishes for `php:8.6.0-fpm-alpine`.
- Before the image swap, this starter ran PHP 8.6.0 compiled from
  the php.net tarball (sha256 verified against php.net), and the
  demo endpoints were exercised against that compiled runtime.
- **Live Railway deploy VERIFIED on 2026-11-20**: a fresh deploy
  of this template went from build start to a passing healthcheck
  in about 1 minute 48 seconds. `/api/health` returned
  `{"status":"ok","php":"8.6.0","opcache":true,"database":"not_configured"}`,
  `/api/info` reported all four PHP 8.6 feature probes true, and
  the status page loaded. The test project was deleted right
  after verification. The database `ok` path (a live Postgres
  attached over `DATABASE_URL`) is still untested for this
  starter; the `error` path (unreachable database returns 503)
  was verified against the earlier build.
