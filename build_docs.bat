@echo off
setlocal
pwsh -NoProfile -File "%~dp0eng\Build-Docs.ps1" %*
exit /b %ERRORLEVEL%
