<#
.SYNOPSIS
  Un solo comando desde la raíz del repo: sube versión en pubspec, compila APK y publica.

.DESCRIPTION
  Misma lógica que scripts/release-apk-local.ps1. Por defecto:
  - Lee ice_pos/pubspec.yaml, incrementa build (+1), guarda pubspec
  - flutter build apk --release
  - Release en GitHub (gh) y opcionalmente app_releases en Supabase (.env)

.EXAMPLE
  .\release-apk.ps1

.EXAMPLE
  .\release-apk.ps1 "Arreglo de cierre de turno"

.EXAMPLE
  .\release-apk.ps1 -BumpVersion patch

.EXAMPLE
  .\release-apk.ps1 1.0.3 4 "Notas manuales"
#>
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
$script = Join-Path $PSScriptRoot "scripts\release-apk-local.ps1"
if (-not (Test-Path -LiteralPath $script)) {
    Write-Error "No se encontró $script"
    exit 1
}
& $script @PSBoundParameters
