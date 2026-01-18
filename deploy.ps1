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

$NGINX_CONF = "C:\nginx\conf\nginx.conf"
$NGINX_EXE  = "C:\nginx\nginx.exe"

# ==========================
# FUNCTIONS
# ==========================
function Get-ActivePortFromNginx {
    param([string]$ConfigPath)

    $lines = Get-Content $ConfigPath

    $primaryPort = $null
    $backupPort  = $null

    foreach ($line in $lines) {
        if ($line -match "server\s+127\.0\.0\.1:([0-9]+).*backup") {
            $backupPort = [int]$matches[1]
        }
        elseif ($line -match "server\s+127\.0\.0\.1:([0-9]+);") {
            $primaryPort = [int]$matches[1]
        }
    }

    if ($primaryPort) { return $primaryPort }
    if ($backupPort)  { return $backupPort }

    throw "Could not determine active port from nginx.conf"
}

function Reload-Nginx {
    Write-Host "Reloading NGINX..." -ForegroundColor Yellow
    & $NGINX_EXE -s reload
}

# ==========================
# DETECT CURRENT / NEXT PORT
# ==========================
$ACTIVE_PORT = Get-ActivePortFromNginx $NGINX_CONF

if ($ACTIVE_PORT -eq $PORT_A) {
    $NEW_PORT = $PORT_B
}
else {
    $NEW_PORT = $PORT_A
}

Write-Host "Active port : $ACTIVE_PORT"
Write-Host "New port    : $NEW_PORT"

# ==========================
# PULL IMAGE
# ==========================
Write-Host "Pulling latest Docker image..."
docker pull $IMAGE

# ==========================
# START NEW CONTAINER
# ==========================
Write-Host "Starting new container on port $NEW_PORT..."

docker run -d `
  --name "$CONTAINER_NAME-$NEW_PORT" `
  -p "${NEW_PORT}:${APP_PORT}" `
  $IMAGE

Start-Sleep -Seconds 5

# ==========================
# HEALTH CHECK
# ==========================
Write-Host "Performing health check..."

$healthUrl = "http://localhost:$NEW_PORT"

try {
    $r = Invoke-WebRequest $healthUrl -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -ne 200) {
        throw "Health check failed"
    }
}
catch {
    Write-Error "Health check FAILED on port $NEW_PORT"
    docker rm -f "$CONTAINER_NAME-$NEW_PORT"
    exit 1
}

Write-Host "Health check PASSED" -ForegroundColor Green

# ==========================
# UPDATE NGINX CONFIG
# ==========================
Write-Host "Updating nginx.conf..."

(Get-Content $NGINX_CONF) `
    -replace "server 127\.0\.0\.1:$ACTIVE_PORT;", "server 127.0.0.1:$ACTIVE_PORT backup;" `
    -replace "server 127\.0\.0\.1:$NEW_PORT backup;", "server 127.0.0.1:$NEW_PORT;" `
| Set-Content $NGINX_CONF

Reload-Nginx

# ==========================
# STOP OLD CONTAINER
# ==========================
Write-Host "Stopping old container on port $ACTIVE_PORT..."
docker rm -f "$CONTAINER_NAME-$ACTIVE_PORT"

Write-Host "=== DEPLOYMENT COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
