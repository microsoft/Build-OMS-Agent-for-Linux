set DIR=%~dp0
set SIGNING_DIR=pipeline-signing
cd /d %DIR%

dir .
dir %DIR%drop

mkdir "%DIR%%SIGNING_DIR%\oms-signing"

Xcopy /Y %DIR%drop\Build_x64\outputs\build\buildoutput\Linux_ULINUX_1.0_x64_64_Release\*.sha256sums %DIR%\%SIGNING_DIR%\oms-signing

dir %DIR%%SIGNING_DIR%\oms-signing

cd %DIR%%SIGNING_DIR%\oms-signing

ren *.sha256sums *.asc

cd /d %DIR%

if %ERRORLEVEL% LSS 8 (
    exit /b 0
) else (
    exit /b %ERRORLEVEL%
)