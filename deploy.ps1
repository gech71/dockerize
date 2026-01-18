Write-Host "Starting ZERO-DOWNTIME deployment with NGINX..." -ForegroundColor Cyan
Write-Host "=== DEPLOYMENT STARTED ===" -ForegroundColor Green

$ErrorActionPreference = "Stop"

# ==========================
# CONFIG
# ==========================
$IMAGE = "ghcr.io/gech71/next-docker-app:latest"

$CONTAINER_NAME = "nextjs-prod"
$APP_PORT = 3000

$PORT_A = 3001
$PORT_B = 3002

$NGINX_ROOT = "C:\nginx"
$NGINX_CONF = "$NGINX_ROOT/conf/nginx.conf"
$NGINX_EXE  = "$NGINX_ROOT/nginx.exe"
$NGINX_LOGS = "$NGINX_ROOT/logs"

# ==========================
# UTILS
# ==========================
function Write-FileUtf8NoBom {
    param (
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# ==========================
# FUNCTIONS
# ==========================
function Get-ActivePortFromNginx {
    param([string]$ConfigPath)

    $content = Get-Content $ConfigPath -Raw

    if ($content -match "server\s+127\.0\.0\.1:(\d+)\s*(?=;)") {
        return $matches[1]
    }

    throw "Could not determine active port from nginx.conf"
}

function Reload-Nginx {
    Write-Host "Reloading NGINX..." -ForegroundColor Yellow

    if (-not (Test-Path $NGINX_LOGS)) {
        Write-Host "Creating NGINX logs directory: $NGINX_LOGS" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $NGINX_LOGS | Out-Null
    }

    Write-Host "NGINX_EXE: $NGINX_EXE" -ForegroundColor Cyan
    Write-Host "NGINX_ROOT: $NGINX_ROOT" -ForegroundColor Cyan
    Write-Host "NGINX_CONF: $NGINX_CONF" -ForegroundColor Cyan

    # ==========================
    # Test nginx config safely
    # ==========================
    $prevErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $testOutput = & $NGINX_EXE -p $NGINX_ROOT -c "conf/nginx.conf" -t 2>&1
    $exitCode = $LASTEXITCODE

    $ErrorActionPreference = $prevErrorAction

    if ($exitCode -ne 0) {
        Write-Host $testOutput -ForegroundColor Red
        throw "NGINX config test failed"
    }

    Write-Host "NGINX config test passed" -ForegroundColor Green

    # ==========================
    # Reload nginx
    # ==========================
    & $NGINX_EXE -p $NGINX_ROOT -c "conf/nginx.conf" -s reload 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Reload failed, restarting NGINX..."
        Stop-Process -Name nginx -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process `
            -FilePath $NGINX_EXE `
            -ArgumentList "-p `"$NGINX_ROOT`" -c `"$NGINX_CONF`"" `
            -NoNewWindow
        Start-Sleep -Seconds 2
        Write-Host "NGINX restarted" -ForegroundColor Green
    }
    else {
        Write-Host "NGINX reloaded successfully" -ForegroundColor Green
    }
}

# ==========================
# DETECT CURRENT / NEXT PORT
# ==========================
Write-Host "`n[1/6] Detecting current deployment state..." -ForegroundColor Cyan

$ACTIVE_PORT = Get-ActivePortFromNginx $NGINX_CONF

if ($ACTIVE_PORT -eq $PORT_A) {
    $NEW_PORT = $PORT_B
    $OLD_CONTAINER_NAME = "$CONTAINER_NAME-$PORT_A"
    $NEW_CONTAINER_NAME = "$CONTAINER_NAME-$PORT_B"
} else {
    $NEW_PORT = $PORT_A
    $OLD_CONTAINER_NAME = "$CONTAINER_NAME-$PORT_B"
    $NEW_CONTAINER_NAME = "$CONTAINER_NAME-$PORT_A"
}

Write-Host "Active port : $ACTIVE_PORT"
Write-Host "New port    : $NEW_PORT"

# ==========================
# CLEANUP EXISTING CONTAINERS
# ==========================
Write-Host "`n[2/6] Cleaning containers..." -ForegroundColor Cyan

# Remove any existing container with the new container name 
if (docker ps -a --filter "name=$NEW_CONTAINER_NAME" --format "{{.Names}}" | Select-Object -First 1) {
    docker rm -f $NEW_CONTAINER_NAME | Out-Null
}

# ==========================
# PULL LATEST IMAGE
# ==========================
Write-Host "`n[3/6] Pulling image..." -ForegroundColor Cyan
docker pull $IMAGE

# ==========================
# START NEW CONTAINER
# ==========================
Write-Host "`n[4/6] Starting new container on port $NEW_PORT..." -ForegroundColor Cyan

$containerId = docker run -d `
    --name $NEW_CONTAINER_NAME `
    -p "${NEW_PORT}:${APP_PORT}" `
    --restart unless-stopped `
    $IMAGE

if (-not $containerId) { throw "Container failed to start" }

Start-Sleep 5

# ==========================
# HEALTH CHECK
# ==========================
Write-Host "`n[5/6] Health check..." -ForegroundColor Cyan

$healthy = $false
for ($i = 1; $i -le 10; $i++) {
    try {
        $r = Invoke-WebRequest "http://localhost:$NEW_PORT" -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch {
        Start-Sleep 3
    }
}

if (-not $healthy) {
    docker logs $NEW_CONTAINER_NAME
    docker rm -f $NEW_CONTAINER_NAME
    throw "Health check failed"
}

# ==========================
# UPDATE NGINX CONFIG
# ==========================
Write-Host "`n[6/6] Updating nginx config..." -ForegroundColor Cyan

$backup = "$NGINX_CONF.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $NGINX_CONF $backup

$content = Get-Content $NGINX_CONF -Raw

$content = $content `
    -replace "server\s+127\.0\.0\.1:$ACTIVE_PORT\s*;", "server 127.0.0.1:$ACTIVE_PORT backup;" `
    -replace "server\s+127\.0\.0\.1:$NEW_PORT\s*backup\s*;", "server 127.0.0.1:$NEW_PORT;"

Write-FileUtf8NoBom -Path $NGINX_CONF -Content $content

Reload-Nginx

# ==========================
# CLEANUP OLD CONTAINER SAFELY
# ==========================
Write-Host "`nCleaning old container..." -ForegroundColor Cyan

$oldContainer = docker ps -a --filter "name=$OLD_CONTAINER_NAME" --format "{{.Names}}"

if ($oldContainer) {
    Write-Host "Stopping old container: $OLD_CONTAINER_NAME"
    docker stop $OLD_CONTAINER_NAME | Out-Null
    Start-Sleep 5
    Write-Host "Removing old container: $OLD_CONTAINER_NAME"
    docker rm $OLD_CONTAINER_NAME | Out-Null
} else {
    Write-Host "Old container $OLD_CONTAINER_NAME not found, skipping cleanup" -ForegroundColor Yellow
}

docker rename $NEW_CONTAINER_NAME "$CONTAINER_NAME-$ACTIVE_PORT" 2>$null | Out-Null

docker image prune -f 2>$null | Out-Null

# ==========================
# FINAL CHECK
# ==========================
Write-Host "`n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
Write-Host "Deployment finished at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
