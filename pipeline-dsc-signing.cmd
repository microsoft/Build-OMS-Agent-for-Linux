set DIR=%~dp0
set SIGNING_DIR=pipeline-signing
cd /d %DIR%

dir .
dir %DIR%drop

mkdir %DIR%%SIGNING_DIR%

Xcopy /E /I /Y %DIR%drop\Build_x64\outputs\build\buildoutput\Linux_ULINUX_1.0_x64_64_Release\dsc %DIR%%SIGNING_DIR%\dsc

mkdir "%DIR%%SIGNING_DIR%\dsc\signing"

powershell -NoProfile -ExecutionPolicy Unrestricted -Command "& '%~dp0pipeline-dsc-signing.ps1'"

if %ERRORLEVEL% LSS 8 (
    exit /b 0
) else (
    exit /b %ERRORLEVEL%
)