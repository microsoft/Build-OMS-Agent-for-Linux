#!/bin/bash
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Start of build step"
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"

BUILD_OUTPUT_DIR="omsagent/target/"

pwd
PWD=`pwd`
pushd $PWD

# Find location of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "WHAT IS HERE?"
ls
# Change to the build folder
echo "Changing to omsagent folder"
cd $DIR/omsagent
echo "WHAT IS HERE?"
ls
echo "Changing to build folder"
cd build
echo "WHAT IS HERE?"
ls
echo "*************************** Run Unit Tests ********************************"
echo "***************************************************************************"
echo "***************************************************************************"
# echo "Configure"
# ./configure --enable-ulinux
# echo "Make unittest"
# make unittest

echo "******************************** Run Make *********************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Configure"
make distclean
./configure --enable-ulinux
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Make"
make

# Save the exit code from react-scripts build
EX=$?
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "WHAT IS HERE?"
ls
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Move back out to omsagent folder"
cd ..
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "WHAT IS HERE?"
ls
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Move back out to root folder"
cd $DIR

# mkdir -p omsagent/target/Linux_ULINUX_1.0_x64_64_Release/dsc 
# cd omsagent/target/Linux_ULINUX_1.0_x64_64_Release/dsc 

# mkdir -p nx
# echo nx123456789 > nx/nx.sha256sums
# echo 123456 > nx/nx.ps1
# zip -r nx_1.5.zip nx
# rm -rf nx

# mkdir -p nxOMSSudoCustomLog
# echo nxOMSSudoCustomLog > nxOMSSudoCustomLog/nxOMSSudoCustomLog.sha256sums
# echo 123456 > nxOMSSudoCustomLog/nxOMSSudoCustomLog.ps1
# zip -r nxOMSSudoCustomLog_2.7.zip nxOMSSudoCustomLog
# rm -rf nxOMSSudoCustomLog
# cd $DIR

echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "WHAT IS HERE?"
ls
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Check Make Exit Code"
# Check exit code and exit with it if it is non-zero so that build will fail
if [ "$EX" -ne "0"  ]; then
  popd
  echo "Build Failed.  Make exited with Exit Code $EX".
  exit $EX
fi
echo "Check Exists: Build Output Folder $BUILD_OUTPUT_DIR"
if [ ! -d "$BUILD_OUTPUT_DIR" ]; then
  popd
  echo "Build failed. Missing expected output folder: $BUILD_OUTPUT_DIR."
  exit 1
fi

echo Build success.
# Restore working directory
popd

# Exit with explicit 0 exit code so build will not fail
exit $EX
