# Borra todas las tareas del personal en Supabase (respuestas, tareas y plantillas).
# Usa el SQL en supabase/scripts/clear_all_staff_tasks.sql vía CLI (requiere proyecto enlazado).

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$SqlFile = Join-Path $ProjectDir "supabase\scripts\clear_all_staff_tasks.sql"

if (-not (Test-Path $SqlFile)) {
    Write-Error "No existe $SqlFile"
}

Push-Location $ProjectDir
try {
    supabase db query --linked --yes -f $SqlFile -o table
    Write-Host "Listo. Refresca Tareas del personal en la app."
} finally {
    Pop-Location
}
