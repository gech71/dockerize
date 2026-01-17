Write-Host "Starting ZERO-DOWNTIME deployment with NGINX..." -ForegroundColor Cyan
$ErrorActionPreference = "Stop"

# ==========================
# CONFIG
# ==========================
$IMAGE = "ghcr.io/gech71/next-docker-app:latest"

$OLD_CONTAINER = "nextjs-prod"
$NEW_CONTAINER = "nextjs-prod-new"

$OLD_PORT = 3001
$NEW_PORT = 3002
$APP_PORT = 3000

$NGINX_CONF = "C:\nginx\conf\nginx.conf"
$NGINX_EXE  = "C:\nginx\nginx.exe"

# ==========================
# PRE-CLEAN (idempotent)
# ==========================
Write-Host "Cleaning previous failed deployment (if any)..."
docker rm -f $NEW_CONTAINER *> $null
# ==========================
# START NEW CONTAINER
# ==========================
Write-Host "Starting new container on port $NEW_PORT..."

$containerId = docker run -d `
  --name $NEW_CONTAINER `
  -p "${NEW_PORT}:${APP_PORT}" `
  $IMAGE

if (-not $containerId) {
    Write-Error "Docker failed to start the new container"
    exit 1
}

# ==========================
# WAIT FOR APP TO BOOT
# ==========================
Start-Sleep -Seconds 10

# ==========================
# VERIFY CONTAINER IS RUNNING
# ==========================
$running = docker ps --filter "name=$NEW_CONTAINER" --format "{{.Names}}"
if ($running -ne $NEW_CONTAINER) {
    Write-Error "New container is not running"
    exit 1
}

# ==========================
# HEALTH CHECK
# ==========================
Write-Host "Running health check..."

try {
    $r = Invoke-WebRequest "http://localhost:$NEW_PORT" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -ne 200) {
        throw "Health check failed"
    }
}
catch {
    Write-Error "Health check failed. Rolling back."
    docker rm -f $NEW_CONTAINER 2>$null
    exit 1
}

Write-Host "Health check passed." -ForegroundColor Green

# ==========================
# SWITCH NGINX TRAFFIC
# ==========================
Write-Host "Switching NGINX upstream..."

(Get-Content $NGINX_CONF) `
  -replace "server 127.0.0.1:$OLD_PORT;", "server 127.0.0.1:$NEW_PORT;" |
  Set-Content $NGINX_CONF

# Graceful reload (NO downtime)
& $NGINX_EXE -c $NGINX_CONF -s reload

Write-Host "Traffic switched instantly." -ForegroundColor Green

# ==========================
# CLEANUP OLD CONTAINER
# ==========================

Write-Host "Cleaning up old container..."
$oldExists = docker ps -a --filter "name=$OLD_CONTAINER" --format "{{.Names}}"
if ($oldExists -eq $OLD_CONTAINER) {
    docker rm -f $OLD_CONTAINER | Out-Null
}
docker rename $NEW_CONTAINER $OLD_CONTAINER

Write-Host "Deployment completed with ZERO DOWNTIME!" -ForegroundColor Green
