# Run ice_pos/supabase/scripts/close_all_open_shifts_and_open_new.sql against Postgres (Supabase).
# Edit the DECLARE variables inside the SQL file before running.
#
# Usage:
#   $env:SUPABASE_DB_URL = "postgresql://postgres.[REF]:[PASSWORD]@..."
#   .\scripts\close-open-shifts-and-open-new.ps1
#
# Requires: psql in PATH. If URL is missing, prints the SQL path for Dashboard paste.

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlFile = Join-Path $repoRoot "ice_pos\supabase\scripts\close_all_open_shifts_and_open_new.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Error "SQL not found at $sqlFile"
}

$dbUrl = $env:SUPABASE_DB_URL
if (-not $dbUrl) { $dbUrl = $env:DATABASE_URL }

if ($dbUrl -and (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Host "Running close_all_open_shifts_and_open_new.sql via psql..."
    & psql $dbUrl -v ON_ERROR_STOP=1 -f $sqlFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Done."
} else {
    Write-Host "Set SUPABASE_DB_URL (or DATABASE_URL) and install psql, or run the SQL in Supabase Dashboard."
    Write-Host ""
    Write-Host "File to open and edit (store_id, starting_fund, etc.):"
    Write-Host "  $sqlFile"
    Write-Host ""
}
