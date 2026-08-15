# Invoca notify-due-staff-tasks (recordatorios con notify_at vencido).
# Programar en Programador de tareas de Windows cada 15 min, o ejecutar a mano.
#
# Requiere: ice_pos/.env con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (o anon si la función lo permite).

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path (Split-Path -Parent $ScriptDir) ".env"
if (-not (Test-Path $EnvFile)) {
    Write-Error "No existe $EnvFile"
}
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        Set-Item -Path "Env:$($matches[1].Trim())" -Value $matches[2].Trim()
    }
}
if (-not $env:SUPABASE_URL) { Write-Error "Falta SUPABASE_URL en .env" }
$key = $env:SUPABASE_SERVICE_ROLE_KEY
if (-not $key) {
    Write-Warning "SUPABASE_SERVICE_ROLE_KEY no en .env; usando SUPABASE_ANON_KEY"
    $key = $env:SUPABASE_ANON_KEY
}
if (-not $key) { Write-Error "Falta clave Supabase en .env" }

$uri = "$($env:SUPABASE_URL.TrimEnd('/'))/functions/v1/notify-due-staff-tasks"
$headers = @{
    Authorization = "Bearer $key"
    apikey        = $key
    "Content-Type" = "application/json"
}
$res = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body "{}"
$res | ConvertTo-Json
