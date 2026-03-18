# Prueba la API de app_releases con la misma URL y anon key que la app.
# Si devuelve filas = RLS/API OK; si devuelve [] = ejecuta 008_app_releases_rls.sql en ESE proyecto.
# Uso: .\ice_pos\scripts\test_app_releases_api.ps1
# Requiere: ice_pos/.env con SUPABASE_URL y SUPABASE_ANON_KEY.

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path (Split-Path -Parent $ScriptDir) ".env"
if (-not (Test-Path -LiteralPath $EnvFile)) {
  Write-Host "No existe $EnvFile. Crea el archivo con SUPABASE_URL y SUPABASE_ANON_KEY."
  exit 1
}
Get-Content $EnvFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
    Set-Item -Path "Env:$($matches[1].Trim())" -Value $matches[2].Trim()
  }
}
if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
  Write-Host "Faltan SUPABASE_URL o SUPABASE_ANON_KEY en .env"
  exit 1
}
$url = "$($env:SUPABASE_URL)/rest/v1/app_releases?select=version,build_number,download_url&order=build_number.desc&limit=1"
Write-Host "GET $url"
$hostPart = ([System.Uri]$env:SUPABASE_URL).Host
Write-Host "Host: $hostPart"
$headers = @{
  "apikey"       = $env:SUPABASE_ANON_KEY
  "Authorization" = "Bearer $($env:SUPABASE_ANON_KEY)"
  "Accept"        = "application/json"
}
try {
  $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing
  Write-Host "HTTP $($response.StatusCode)"
  $body = $response.Content
  if ($body.Length -gt 500) { $body = $body.Substring(0, 500) + "..." }
  Write-Host $body
  if ($response.StatusCode -ne 200) {
    Write-Host "Error: la API no devolvió 200. Revisa RLS (008_app_releases_rls.sql) en ese proyecto."
    exit 1
  }
  if ($body -eq "[]" -or [string]::IsNullOrWhiteSpace($body)) {
    Write-Host "La API devolvió vacío. Ejecuta en Supabase SQL Editor (proyecto con host arriba):"
    Write-Host "  supabase/migrations/008_app_releases_rls.sql"
    exit 1
  }
  Write-Host "OK: la API devuelve datos. Si la app sigue sin verlos, revisa que la app use el mismo .env al compilar."
} catch {
  Write-Host "Error: $_"
  exit 1
}
