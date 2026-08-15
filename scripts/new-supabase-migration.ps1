<#
.SYNOPSIS
  Creates the next numbered SQL migration under ice_pos/supabase/migrations/.

.DESCRIPTION
  Uses ice_pos/supabase/migrations/.migration_seq (last applied number) and scans
  existing *.sql files so the next id is max(stored, max prefix in folder) + 1.
  You pass only a descriptive slug (no version).

.PARAMETER Name
  Short snake_case or phrase; will be normalized to a safe filename suffix.

.EXAMPLE
  .\scripts\new-supabase-migration.ps1 add_loyalty_points
  # creates 027_add_loyalty_points.sql and updates .migration_seq
#>
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string] $Name
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$migrationsDir = Join-Path $repoRoot "ice_pos\supabase\migrations"
$seqFile = Join-Path $migrationsDir ".migration_seq"

if (-not (Test-Path $migrationsDir)) {
  Write-Error "Migrations folder not found: $migrationsDir"
}

function Get-MaxPrefixFromFiles {
  param([string] $Dir)
  $max = 0
  Get-ChildItem -Path $Dir -Filter "*.sql" -File | ForEach-Object {
    if ($_.Name -match '^(\d{3})_') {
      $n = [int]$Matches[1]
      if ($n -gt $max) { $max = $n }
    }
  }
  return $max
}

$stored = 0
if (Test-Path $seqFile) {
  $raw = (Get-Content -LiteralPath $seqFile -Raw).Trim()
  if ($raw -match '^\d+$') { $stored = [int]$raw }
}

$fromFiles = Get-MaxPrefixFromFiles -Dir $migrationsDir
$next = [Math]::Max($stored, $fromFiles) + 1
if ($next -gt 999) {
  Write-Error "Migration id would exceed 999; switch to another scheme or reset."
}

$slug = ($Name -replace '[^a-zA-Z0-9]+', '_').Trim('_').ToLowerInvariant()
if ([string]::IsNullOrEmpty($slug)) {
  Write-Error "Name produced an empty slug."
}

$padded = $next.ToString("000")
$fileName = "${padded}_${slug}.sql"
$dest = Join-Path $migrationsDir $fileName

if (Test-Path -LiteralPath $dest) {
  Write-Error "File already exists: $dest"
}

$header = @"
-- Migration ${padded}: $slug
-- Created $(Get-Date -Format "yyyy-MM-dd")

"@

Set-Content -LiteralPath $dest -Value $header -Encoding utf8
Set-Content -LiteralPath $seqFile -Value "$next`n" -Encoding utf8 -NoNewline:$false

Write-Host "Created $dest"
Write-Host "Updated .migration_seq -> $next"
