Param(
  [Parameter(Mandatory = $false)]
  [string]$StorageAccount = "luju",

  [Parameter(Mandatory = $false)]
  [string]$BuildSource = "c:\Users\jvald\code\icepos\ice_pos\build\web",

  [Parameter(Mandatory = $false)]
  [string]$VapidPublicKey = ""
)

$ErrorActionPreference = "Stop"

function Assert-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "No se encontro el comando '$name'. Instalalo antes de continuar."
  }
}

Assert-Command "flutter"
Assert-Command "az"

Write-Host "==> Build Flutter web (sin SW offline de Flutter)..." -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($VapidPublicKey)) {
  flutter build web --pwa-strategy=none --no-wasm-dry-run
} else {
  flutter build web --pwa-strategy=none --no-wasm-dry-run --dart-define="WEB_PUSH_VAPID_PUBLIC_KEY=$VapidPublicKey"
}
if ($LASTEXITCODE -ne 0) {
  throw "flutter build web falló (exit $LASTEXITCODE). No se subió nada a Azure."
}

if (-not (Test-Path $BuildSource)) {
  throw "No existe la carpeta build web: $BuildSource"
}

Write-Host "==> Subiendo archivos a `$web..." -ForegroundColor Cyan
az storage blob upload-batch `
  --account-name $StorageAccount `
  --auth-mode login `
  --destination '$web' `
  --source $BuildSource `
  --overwrite | Out-Null

Write-Host "==> Aplicando cache-control no-cache a archivos criticos..." -ForegroundColor Cyan
$noCacheFiles = @(
  "index.html",
  "flutter_bootstrap.js",
  "main.dart.js",
  "manifest.json",
  "version.json"
)

foreach ($f in $noCacheFiles) {
  try {
    az storage blob update `
      --account-name $StorageAccount `
      --auth-mode login `
      --container-name '$web' `
      --name $f `
      --content-cache-control "no-cache, no-store, must-revalidate, max-age=0" | Out-Null
    Write-Host "  OK $f"
  } catch {
    Write-Host "  WARN no se pudo actualizar cache-control de $f (puede no existir en este build)." -ForegroundColor Yellow
  }
}

Write-Host "==> Aplicando cache-control largo a assets..." -ForegroundColor Cyan
# update-batch no existe en todas las versiones de Azure CLI; omitir si falla.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
az storage blob update-batch `
  --account-name $StorageAccount `
  --auth-mode login `
  --destination '$web/assets' `
  --pattern "*" `
  --content-cache-control "public, max-age=31536000, immutable" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "  WARN update-batch no disponible; assets sin cache-control extra." -ForegroundColor Yellow
}
$ErrorActionPreference = $prevEap

$webUrl = az storage account show `
  --name $StorageAccount `
  --query "primaryEndpoints.web" `
  -o tsv

Write-Host ""
Write-Host "Deploy completado." -ForegroundColor Green
Write-Host "URL: $webUrl" -ForegroundColor Green

