mkdir pipeline-signing

dir c:\temppriordrop\current\Linux_ULINUX_1.0_x64_64_Release\dsc

cp c:\temppriordrop\current\Linux_ULINUX_1.0_x64_64_Release\dsc .pipeline-signing\

mkdir "pipeline-signing\dsc\signing"

Xcopy /E /I pipeline-signing\dsc\*.sha256sums pipeline-signing\dsc\signing

dir pipeline-signing\dsc\signing