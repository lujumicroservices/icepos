# Backup: generar APK y publicar release desde tu computadora (sin depender de GitHub Actions).
#
# Requisitos:
#   - Flutter instalado y en PATH
#   - GitHub CLI (gh) instalado y autenticado: winget install GitHub.cli
#   - Opcional: SUPABASE_URL y SUPABASE_ANON_KEY en el entorno o en ice_pos/.env
#
# Uso:
#   .\scripts\release-apk-local.ps1 1.0.3 4
#   .\scripts\release-apk-local.ps1 1.0.3 4 "Corrección de impresión"
#   .\scripts\release-apk-local.ps1 -Version 1.0.3 -Build 4 -Message "Corrección de impresión"
#
# Parámetros:
#   Version  = versión (ej. 1.0.3)
#   Build    = build number (entero). Android permite hasta 2100000000.
#   Message  = mensaje opcional para la release (default: "Nueva versión disponible.")

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version,
    [Parameter(Mandatory = $true, Position = 1)]
    [int]$Build,
    [Parameter(Position = 2)]
    [string]$Message = "Nueva versión disponible."
)

$ErrorActionPreference = "Stop"
$MAX_BUILD = 2100000000
if ($Build -gt $MAX_BUILD) {
    Write-Host "Build number se limita a $MAX_BUILD (límite Android)."
    $Build = $MAX_BUILD
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$IcePos = Join-Path $RepoRoot "ice_pos"
$ApkPath = Join-Path $IcePos "build\app\outputs\flutter-apk\app-release.apk"

Set-Location $RepoRoot

Write-Host "==> Versión: $Version, Build: $Build"
Write-Host "==> Compilando APK..."
Set-Location $IcePos
flutter pub get
flutter build apk --release --build-name="$Version" --build-number="$Build"
Set-Location $RepoRoot

if (-not (Test-Path -LiteralPath $ApkPath)) {
    Write-Error "Error: no se generó $ApkPath"
    exit 1
}

Write-Host "==> Creando release en GitHub..."
gh release create "v$Version" $ApkPath `
    --title "Release $Version" `
    --notes $Message `
    --latest

Write-Host "==> Actualizando Supabase app_releases (si hay credenciales)..."

# Cargar .env de ice_pos si existe (formato KEY=value)
$EnvPath = Join-Path $IcePos ".env"
if (Test-Path -LiteralPath $EnvPath) {
    Get-Content $EnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            Set-Item -Path "Env:$key" -Value $val
        }
    }
}

if ($env:SUPABASE_URL -and $env:SUPABASE_ANON_KEY) {
    $RepoSlug = gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
    if (-not $RepoSlug) {
        Write-Host "No se pudo obtener repo (gh repo view). Pasa SUPABASE_* y usa DOWNLOAD_URL manual si hace falta."
    } else {
        $DownloadUrl = "https://github.com/$RepoSlug/releases/download/v$Version/app-release.apk"
        # Build JSON manually so PostgREST receives valid UTF-8 (ConvertTo-Json / -Body can break encoding on Windows)
        $MessageEscaped = $Message -replace '\\', '\\\\' -replace "`r", '' -replace "`n", ' ' -replace '"', '\"'
        $BodyStr = "{`"version`":`"$Version`",`"build_number`":$Build,`"download_url`":`"$DownloadUrl`",`"message_es`":`"$MessageEscaped`"}"
        $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($BodyStr)

        $Headers = @{
            "apikey"        = $env:SUPABASE_ANON_KEY
            "Authorization" = "Bearer $($env:SUPABASE_ANON_KEY)"
            "Content-Type"  = "application/json; charset=utf-8"
            "Prefer"        = "return=minimal"
        }
        Invoke-RestMethod -Uri "$($env:SUPABASE_URL)/rest/v1/app_releases" -Method Post -Headers $Headers -Body $BodyBytes
        Write-Host "Supabase app_releases actualizado."
    }
} else {
    Write-Host "SUPABASE_URL o SUPABASE_ANON_KEY no configurados. Omitiendo Supabase."
    Write-Host "  Para activar: `$env:SUPABASE_URL='...'; `$env:SUPABASE_ANON_KEY='...' o añádelos a ice_pos/.env"
}

$RepoSlugDisplay = gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
if (-not $RepoSlugDisplay) { $RepoSlugDisplay = "OWNER/REPO" }
Write-Host ""
Write-Host "Listo. Release v$Version publicada."
Write-Host "  APK: $ApkPath"
Write-Host "  URL: https://github.com/$RepoSlugDisplay/releases/tag/v$Version"
