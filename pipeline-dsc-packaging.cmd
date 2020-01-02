set DIR=%~dp0
cd /d %DIR%

powershell -NoProfile -ExecutionPolicy Unrestricted -Command "& '%~dp0pipeline-dsc-packaging.ps1'"
exit /B %ERRORLEVEL%