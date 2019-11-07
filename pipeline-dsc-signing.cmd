

dir c:\

dir c:\temppriordrop\

dir c:\temppriordrop\current\

dir c:\temppriordrop\current\Linux_ULINUX_1.0_x64_64_Release\

dir c:\temppriordrop\current\Linux_ULINUX_1.0_x64_64_Release\dsc


mkdir .pipeline-signing

Xcopy /E /I /Y c:\temppriordrop\current\Linux_ULINUX_1.0_x64_64_Release\dsc .pipeline-signing\dsc

mkdir ".pipeline-signing\dsc\signing"

Xcopy .pipeline-signing\dsc\*.sha256sums .pipeline-signing\dsc\signing /Y /M

dir .pipeline-signing\dsc\signing