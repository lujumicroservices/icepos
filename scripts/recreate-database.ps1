# Recreate Supabase database from scratch (run consolidated SQL).
# Usage: .\scripts\recreate-database.ps1
# Requires: SUPABASE_DB_URL or DATABASE_URL with full postgres connection string (including password).
# If not set, prints instructions to run the SQL in Supabase Dashboard.

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlFile = Join-Path $repoRoot "ice_pos\supabase\recreate_database.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Error "recreate_database.sql not found at $sqlFile"
}

$dbUrl = $env:SUPABASE_DB_URL
if (-not $dbUrl) { $dbUrl = $env:DATABASE_URL }

if ($dbUrl -and (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Host "Running recreate_database.sql via psql..."
    & psql $dbUrl -f $sqlFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Done. Database recreated."
} else {
    Write-Host "To run the script via command line, set SUPABASE_DB_URL (or DATABASE_URL) and have psql in PATH."
    Write-Host ""
    Write-Host "Example:"
    Write-Host '  $env:SUPABASE_DB_URL = "postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"'
    Write-Host "  .\scripts\recreate-database.ps1"
    Write-Host ""
    Write-Host "Otherwise, run the SQL manually in Supabase Dashboard > SQL Editor:"
    Write-Host "  File: $sqlFile"
    Write-Host ""
}
