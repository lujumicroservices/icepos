@echo off
REM Prueba la API app_releases con el .env de ice_pos (misma URL/key que la app).
REM Uso: desde ice_pos, scripts\test_app_releases_api.cmd
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_app_releases_api.ps1" %*
exit /b %ERRORLEVEL%
