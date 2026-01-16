# c:\deploy\deploy.ps1
Write-Host "Starting ZERO-DOWNTIME deployment with NGINX..." -ForegroundColor Cyan
$ErrorActionPreference = "Stop"

# ==========================
# CONFIG
# ==========================
$IMAGE = "nextjs-web:latest"

$OLD_CONTAINER = "nextjs-prod"
$NEW_CONTAINER = "nextjs-prod-new"

$OLD_PORT = 3001
$NEW_PORT = 3002
$APP_PORT = 3000

$NGINX_CONF = "C:\nginx\conf\nginx.conf"

# ==========================
# START NEW CONTAINER
# ==========================
Write-Host "Starting new container on port $NEW_PORT..."

docker run -d `
  --name $NEW_CONTAINER `
  -p "${NEW_PORT}:${APP_PORT}" `
  $IMAGE

Start-Sleep -Seconds 5

# ==========================
# HEALTH CHECK
# ==========================
try {
    $r = Invoke-WebRequest "http://localhost:$NEW_PORT" -TimeoutSec 5
    if ($r.StatusCode -ne 200) {
        throw "Health check failed"
    }
}
catch {
    Write-Error "New version failed health check. Rolling back."
    docker rm -f $NEW_CONTAINER
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

# Reload NGINX (NO downtime)
& C:\nginx\nginx.exe -s reload

Write-Host "Traffic switched instantly." -ForegroundColor Green

# ==========================
# CLEANUP OLD CONTAINER
# ==========================
docker rm -f $OLD_CONTAINER -ErrorAction SilentlyContinue
docker rename $NEW_CONTAINER $OLD_CONTAINER

Write-Host "Deployment completed with ZERO DOWNTIME!" -ForegroundColor Green