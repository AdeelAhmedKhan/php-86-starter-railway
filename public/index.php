<?php
// PHP 8.6 starter — single entry point (nginx routes everything here).
// No framework, no Composer dependencies: this file IS the demo app.
// Replace it with your own application; keep /api/health honest.

declare(strict_types=1);

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

function json(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES), "\n";
}

// Database check: only attempted when DATABASE_URL is set (Railway
// Postgres reference). Returns 'not_configured', 'ok', or 'error'.
// The health endpoint never fakes this: a configured database that
// does not answer makes the health check fail with 503.
function databaseStatus(): string
{
    $url = getenv('DATABASE_URL') ?: '';
    if ($url === '') {
        return 'not_configured';
    }
    $parts = parse_url($url);
    if ($parts === false || !isset($parts['host'])) {
        return 'error';
    }
    $dsn = sprintf(
        'pgsql:host=%s;port=%d;dbname=%s;connect_timeout=3',
        $parts['host'],
        $parts['port'] ?? 5432,
        ltrim($parts['path'] ?? '', '/')
    );
    try {
        $pdo = new PDO($dsn, urldecode($parts['user'] ?? ''), urldecode($parts['pass'] ?? ''), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        $pdo->query('SELECT 1');
        return 'ok';
    } catch (Throwable) {
        return 'error';
    }
}

if ($path === '/api/health') {
    $db = databaseStatus();
    $opcache = null;
    if (function_exists('opcache_get_status')) {
        $status = opcache_get_status(false);
        $opcache = is_array($status) ? (bool) ($status['opcache_enabled'] ?? false) : false;
    }
    json([
        'status' => $db === 'error' ? 'degraded' : 'ok',
        'php' => PHP_VERSION,
        'opcache' => $opcache,
        'database' => $db,
    ], $db === 'error' ? 503 : 200);
    return;
}

if ($path === '/api/info') {
    // Runtime probes for headline PHP 8.6 features. Each is checked
    // against the real runtime, not assumed from the version string.
    json([
        'php' => PHP_VERSION,
        'sapi' => PHP_SAPI,
        'features_php_8_6' => [
            'clamp_function' => function_exists('clamp'),
            'time_duration_class' => class_exists('Time\Duration'),
            'sort_direction_enum' => enum_exists('SortDirection'),
            'io_poll_api' => class_exists('Io\Poll\Context'),
        ],
        'extensions' => [
            'pdo_pgsql' => extension_loaded('pdo_pgsql'),
            'pdo_sqlite' => extension_loaded('pdo_sqlite'),
            'intl' => extension_loaded('intl'),
            'mbstring' => extension_loaded('mbstring'),
            'zip' => extension_loaded('zip'),
            'curl' => extension_loaded('curl'),
            'sodium' => extension_loaded('sodium'),
        ],
    ]);
    return;
}

if ($path === '/') {
    $version = htmlspecialchars(PHP_VERSION, ENT_QUOTES);
    header('Content-Type: text/html; charset=utf-8');
    echo <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PHP 8.6 Starter</title>
<style>
  body { font-family: ui-sans-serif, system-ui, sans-serif; margin: 3rem auto; max-width: 40rem; padding: 0 1rem; color: #1a1a18; line-height: 1.55; }
  code { background: #f0efe9; padding: 0.1em 0.35em; border-radius: 4px; }
  h1 { font-size: 1.6rem; }
  .muted { color: #5c5a52; }
</style>
</head>
<body>
<h1>PHP {$version} is running</h1>
<p>This is the PHP 8.6 starter: PHP 8.6.0 compiled from the official
php.net source, served by nginx and php-fpm as a non-root user.</p>
<p>Endpoints:</p>
<ul>
  <li><a href="/api/health">/api/health</a> — status, PHP version, OPcache, database state</li>
  <li><a href="/api/info">/api/info</a> — PHP 8.6 feature probes and loaded extensions</li>
</ul>
<p class="muted">Replace <code>public/index.php</code> with your own application.
Add a Postgres service and set <code>DATABASE_URL</code> to see the database
check in <code>/api/health</code> turn to <code>ok</code>.</p>
</body>
</html>
HTML;
    return;
}

json(['error' => 'not_found', 'path' => $path], 404);
