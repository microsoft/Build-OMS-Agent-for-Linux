set DIR="%~dp0"
cd /d %DIR%

dir .

dir %DIR%

dir c:\temppriordrop\current\drop

dir %CDP_TEMP_PRIOR_DROP_FOLDER_CONTAINER_PATH%\current\drop\Phase_1\outputs\build\buildoutput

dir %CDP_TEMP_PRIOR_DROP_FOLDER_CONTAINER_PATH%\current\drop\Phase_1\outputs\build\buildoutput\Linux_ULINUX_1.0_x64_64_Release\dsc

mkdir %DIR%\pipeline-signing

Xcopy /E /I /Y %CDP_TEMP_PRIOR_DROP_FOLDER_CONTAINER_PATH%\current\drop\Phase_1\outputs\build\buildoutput\Linux_ULINUX_1.0_x64_64_Release\dsc %DIR%\pipeline-signing\dsc

robocopy %CDP_TEMP_PRIOR_DROP_FOLDER_CONTAINER_PATH%\current\drop\linux_phase\outputs\build\drop %~dp0\%DROP% /e

mkdir "%DIR%\pipeline-signing\dsc\signing"

Xcopy %DIR%\pipeline-signing\dsc\*.sha256sums %DIR%\pipeline-signing\dsc\signing /Y /M

dir %DIR%\pipeline-signing\dsc\signing



if %ERRORLEVEL% LSS 8 (
    exit /b 0
) else (
    exit /b %ERRORLEVEL%
)