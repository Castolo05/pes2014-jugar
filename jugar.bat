@echo off
rem Lanza PES 2014 en Windows (doble clic). Toda la logica esta en jugar.ps1; ver ese archivo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0jugar.ps1" %*
exit /b %ERRORLEVEL%
