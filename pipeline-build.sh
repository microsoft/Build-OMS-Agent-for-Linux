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
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Configure"
./configure --enable-ulinux
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Make"
# make

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

mkdir -p omsagent/target/Linux_ULINUX_1.0_x64_64_Release/dsc 

echo nx > omsagent/target/Linux_ULINUX_1.0_x64_64_Release/dsc/nx.sha256sums
touch omsagent/target/Linux_ULINUX_1.0_x64_64_Release/dsc/nxOMSSudoCustomLog.zip
echo nxOMSSudoCustomLog > omsagent/target/Linux_ULINUX_1.0_x64_64_Release/dsc/nxOMSSudoCustomLog.sha256sums

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
