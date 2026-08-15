# Backup: generar APK y publicar release desde tu computadora (sin depender de GitHub Actions).
#
# Requisitos:
#   - Flutter instalado y en PATH
#   - GitHub CLI (gh) instalado y autenticado: winget install GitHub.cli
#   - Opcional: SUPABASE_URL y SUPABASE_ANON_KEY en el entorno o en ice_pos/.env
#
# Desde la raíz del repo (recomendado — un solo comando):
#   .\release-apk.ps1
#
# Uso (mismo comportamiento desde scripts/):
#   .\scripts\release-apk-local.ps1
#   .\scripts\release-apk-local.ps1 "Conciliación de inventario"
#   .\scripts\release-apk-local.ps1 -BumpVersion patch   # además de +1 en build, sube 4.0.11 -> 4.0.12
#
# Uso manual (como antes):
#   .\scripts\release-apk-local.ps1 1.0.3 4
#   .\scripts\release-apk-local.ps1 1.0.3 4 "Corrección de impresión"
#   .\scripts\release-apk-local.ps1 -Version 1.0.3 -Build 4 -Message "Corrección de impresión"
#   .\scripts\release-apk-local.ps1 1.0.3 4 -SkipBuild   # APK ya compilado; solo sube a GitHub + Supabase

[CmdletBinding(DefaultParameterSetName = "Auto")]
param(
    [Parameter(ParameterSetName = "Manual", Mandatory = $true, Position = 0)]
    [string]$Version,
    [Parameter(ParameterSetName = "Manual", Mandatory = $true, Position = 1)]
    [int]$Build,
    [Parameter(ParameterSetName = "Manual", Position = 2)]
    [Parameter(ParameterSetName = "Auto", Position = 0)]
    [string]$Message = "Nueva versión disponible.",
    [Parameter(ParameterSetName = "Auto")]
    [ValidateSet("none", "patch", "minor", "major")]
    [string]$BumpVersion = "none",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$MAX_BUILD = 2100000000

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$IcePos = Join-Path $RepoRoot "ice_pos"
$PubspecPath = Join-Path $IcePos "pubspec.yaml"
$ApkPath = Join-Path $IcePos "build\app\outputs\flutter-apk\app-release.apk"

function Read-PubspecVersion {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No existe pubspec: $Path"
    }
    $text = [System.IO.File]::ReadAllText($Path)
    $m = [regex]::Match($text, '(?m)^version:\s*(\S+)\s*$')
    if (-not $m.Success) {
        throw "No se encontró la línea version: en pubspec.yaml"
    }
    $token = $m.Groups[1].Value
    if ($token -match '^(\d+\.\d+\.\d+)\+(\d+)$') {
        return @{ Name = $matches[1]; Build = [int]$matches[2] }
    }
    if ($token -match '^(\d+\.\d+\.\d+)$') {
        return @{ Name = $matches[1]; Build = 0 }
    }
    throw "Formato de version no reconocido en pubspec: $token (esperado ej. 4.0.11+51)"
}

function Set-PubspecVersionLine {
    param(
        [string]$Path,
        [string]$Name,
        [int]$BuildNum
    )
    $text = [System.IO.File]::ReadAllText($Path)
    $newLine = "version: $Name+$BuildNum"
    $updated = [regex]::Replace($text, '(?m)^version:\s*\S+\s*$', $newLine, 1)
    if ($updated -eq $text) {
        throw "No se pudo actualizar la línea version: en pubspec.yaml"
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $updated, $utf8NoBom)
}

function Bump-SemverPart {
    param(
        [string]$Name,
        [ValidateSet("patch", "minor", "major")]
        [string]$Part
    )
    $bits = $Name.Split(".")
    if ($bits.Count -ne 3) {
        throw "versionName debe ser major.minor.patch (ej. 4.0.11); recibido: $Name"
    }
    [int]$maj = $bits[0]
    [int]$min = $bits[1]
    [int]$pat = $bits[2]
    switch ($Part) {
        "major" { $maj++; $min = 0; $pat = 0 }
        "minor" { $min++; $pat = 0 }
        "patch" { $pat++ }
    }
    return "$maj.$min.$pat"
}

function Import-IcePosDotEnv {
    param([string]$EnvFilePath)
    if (-not (Test-Path -LiteralPath $EnvFilePath)) { return }
    Get-Content $EnvFilePath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            Set-Item -Path "Env:$key" -Value $val
        }
    }
}

# Mayor build_number ya publicado en app_releases (versionCode global). Si falla la lectura, devuelve 0.
function Get-MaxAppReleaseBuildFromSupabase {
    if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) { return 0 }
    try {
        $uri = "$($env:SUPABASE_URL.TrimEnd('/'))/rest/v1/app_releases?select=build_number&order=build_number.desc.nullslast&limit=1"
        $headers = @{
            "apikey"        = $env:SUPABASE_ANON_KEY
            "Authorization" = "Bearer $($env:SUPABASE_ANON_KEY)"
        }
        $rows = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($null -eq $rows) { return 0 }
        if ($rows -is [System.Array] -and $rows.Count -gt 0 -and $null -ne $rows[0].build_number) {
            return [int]$rows[0].build_number
        }
        if ($rows -isnot [System.Array] -and $null -ne $rows.build_number) {
            return [int]$rows.build_number
        }
    }
    catch {
        Write-Warning "No se pudo leer max(build_number) en app_releases: $($_.Exception.Message). Se usa solo pubspec."
    }
    return 0
}

Set-Location $RepoRoot

$EnvPathEarly = Join-Path $IcePos ".env"
Import-IcePosDotEnv -EnvFilePath $EnvPathEarly

if ($PSCmdlet.ParameterSetName -eq "Auto") {
    $cur = Read-PubspecVersion -Path $PubspecPath
    $name = $cur.Name
    if ($BumpVersion -ne "none") {
        $name = Bump-SemverPart -Name $name -Part $BumpVersion
    }
    $nextFromPubspec = $cur.Build + 1
    $maxPublished = Get-MaxAppReleaseBuildFromSupabase
    # Evita reiniciar versionCode al cambiar de rama semver (p. ej. 5.0.0+2 tras 4.0.11+51): siempre > max en BD.
    $Build = [Math]::Max($nextFromPubspec, $maxPublished + 1)
    $Version = $name
    if ($maxPublished -gt 0 -and $Build -ne $nextFromPubspec) {
        Write-Host "==> Ajuste build: pubspec+1 sería $nextFromPubspec pero app_releases llega a $maxPublished -> usando $Build (versionCode monotónico)."
    }
    if ($Build -gt $MAX_BUILD) {
        Write-Host "Build number se limita a $MAX_BUILD (límite Android)."
        $Build = $MAX_BUILD
    }
    Write-Host "==> Auto: pubspec era $($cur.Name)+$($cur.Build) -> publicando $Version+$Build"
    Set-PubspecVersionLine -Path $PubspecPath -Name $Version -BuildNum $Build
} else {
    if ($Build -gt $MAX_BUILD) {
        Write-Host "Build number se limita a $MAX_BUILD (límite Android)."
        $Build = $MAX_BUILD
    }
    Write-Host "==> Manual: Versión: $Version, Build: $Build"
}

if ($SkipBuild) {
    Write-Host "==> SkipBuild: no se ejecuta flutter build (debe existir un APK ya compilado con esta versión/build)."
} else {
    Write-Host "==> Compilando APK..."
    Set-Location $IcePos
    flutter pub get
    flutter build apk --release --build-name="$Version" --build-number="$Build"
    Set-Location $RepoRoot
}

if (-not (Test-Path -LiteralPath $ApkPath)) {
    Write-Error "Error: no se generó $ApkPath"
    exit 1
}

# Tag único por build (mismo versionName + distinto versionCode => sin colisión en GitHub)
$ReleaseTag = "v$Version-b$Build"

Write-Host "==> Creando release en GitHub (tag $ReleaseTag)..."
gh release create $ReleaseTag $ApkPath `
    --title "Release $Version (build $Build)" `
    --notes $Message `
    --latest

Write-Host "==> Actualizando Supabase app_releases (si hay credenciales)..."

# .env ya cargado al inicio (Import-IcePosDotEnv); por si se añadió SUPABASE_* después, volver a leer
Import-IcePosDotEnv -EnvFilePath $EnvPathEarly

if ($env:SUPABASE_URL -and $env:SUPABASE_ANON_KEY) {
    $RepoSlug = gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
    if (-not $RepoSlug) {
        Write-Host "No se pudo obtener repo (gh repo view). Pasa SUPABASE_* y usa DOWNLOAD_URL manual si hace falta."
    } else {
        $DownloadUrl = "https://github.com/$RepoSlug/releases/download/$ReleaseTag/app-release.apk"
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
Write-Host "Listo. Release $ReleaseTag publicada."
Write-Host "  APK: $ApkPath"
Write-Host "  URL: https://github.com/$RepoSlugDisplay/releases/tag/$ReleaseTag"
Write-Host "  Recuerda hacer commit de ice_pos/pubspec.yaml (version: $Version+$Build)."
