# AGENTS.md — PHP 8.6 Starter

Rules for anyone (human or agent) changing this template:

- Never fake capability. `/api/health` must report the real database
  state: `ok` only after a real `SELECT 1` succeeds, `error` (with
  HTTP 503) when a configured database does not answer, and
  `not_configured` when `DATABASE_URL` is unset.
- `/api/info` feature flags must be real runtime probes
  (`function_exists`, `class_exists`, `extension_loaded`), never
  hardcoded from the version string.
- The PHP version is pinned twice in the Dockerfile: the image tag
  (`php:8.6.0-fpm-alpine`) and its amd64 digest (`@sha256:...`), the
  digest being the value Docker Hub publishes for that tag. Never
  bump one without the other, and verify the new digest on Docker
  Hub before pushing.
- History: on release day (2026-11-19) Docker Hub had no final
  8.6.0 tags, so this starter originally compiled PHP from the
  php.net tarball pinned by its sha256. The official tags landed
  the same day and the build moved to the official image; the app,
  nginx config, and entrypoint did not change in that swap.
- The container runs as www-data. Nothing at runtime may write to
  /etc/nginx or /usr/local/etc; runtime writes go to /run/nginx.
- OPcache is built into PHP 8.6. Do not add an opcache install step;
  there is no shared module to install.
- Keep the demo app dependency-free (no Composer packages). Composer
  itself ships in the image for users who add their own.
