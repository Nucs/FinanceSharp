@echo off
setlocal
pushd "%~dp0.."
if errorlevel 1 exit /b 1
pwsh -NoProfile -File eng/Build-Docs.ps1 -Serve
set "docfx_exit=%ERRORLEVEL%"
popd
exit /b %docfx_exit%
