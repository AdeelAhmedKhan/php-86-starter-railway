# AGENTS.md — PHP 8.6 Starter

Rules for anyone (human or agent) changing this template:

- Never fake capability. `/api/health` must report the real database
  state: `ok` only after a real `SELECT 1` succeeds, `error` (with
  HTTP 503) when a configured database does not answer, and
  `not_configured` when `DATABASE_URL` is unset.
- `/api/info` feature flags must be real runtime probes
  (`function_exists`, `class_exists`, `extension_loaded`), never
  hardcoded from the version string.
- The PHP version is pinned twice: `PHP_VERSION` and `PHP_SHA256` in
  the Dockerfile, the sha256 being the value php.net publishes on its
  downloads page for that exact tarball. Never bump one without the
  other, and never drop the checksum verification step.
- When Docker Hub's official `php:8.6.x-fpm-alpine` image exists, the
  from-source stage is replaced by it and this file's pinning rule
  moves to the image tag + digest. The app, nginx config, and
  entrypoint do not change in that swap.
- The container runs as www-data. Nothing at runtime may write to
  /etc/nginx or /usr/local/etc; runtime writes go to /run/nginx.
- OPcache is built into PHP 8.6. Do not add an opcache install step;
  there is no shared module to install.
- Keep the demo app dependency-free (no Composer packages). Composer
  itself ships in the image for users who add their own.
