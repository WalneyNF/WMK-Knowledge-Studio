@echo off
cd /d "%~dp0"
powershell -NoProfile -Command "Get-Command uv,node,npm.cmd,surreal -ErrorAction SilentlyContinue | Select-Object Name,Source; Get-PSDrive -PSProvider FileSystem; Get-NetTCPConnection -State Listen -LocalPort 8000,5055,3000,11434 -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess; Get-ChildItem wmk-logs -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTime"
pause
