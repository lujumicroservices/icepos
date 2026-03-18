@echo off
REM Publicar release APK desde Windows (genera APK, crea release en GitHub, actualiza Supabase).
REM Uso: release-apk-local.cmd 1.0.12 12
REM      release-apk-local.cmd 1.0.12 12 "Mensaje opcional"
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-apk-local.ps1" %*
exit /b %ERRORLEVEL%
