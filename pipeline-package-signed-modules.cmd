set DIR=%~dp0
cd /d %DIR%

dir .



if %ERRORLEVEL% LSS 8 (
    exit /b 0
) else (
    exit /b %ERRORLEVEL%
)