#!/bin/bash
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Start of Extension Packaging "
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OUTPUT_DIR="${SOURCE_DIR}/pipeline-extension-packaging"
mkdir $OUTPUT_DIR

set -x
pwd
PWD=`pwd`
pushd $PWD

ROOT_DROP_DIR="${CDP_TEMP_PRIOR_DROP_FOLDER_CONTAINER_PATH}/current/drop"
echo "ROOT_DROP_DIR=${ROOT_DROP_DIR}"
echo "ls -la $ROOT_DROP_DIR"
ls -la $ROOT_DROP_DIR

BUILD_X86_DROP_DIR=$ROOT_DROP_DIR/Build_x64/outputs/build/buildoutput/Linux_ULINUX_1.0_x64_64_Release
echo "BUILD_X86_DROP_DIR=${BUILD_X86_DROP_DIR}"
echo "tree -f $BUILD_X86_DROP_DIR"
tree -f $BUILD_X86_DROP_DIR

SIGNING_DROP_DIR=$ROOT_DROP_DIR/Signing/outputs/
echo "SIGNING_DROP_DIR=${SIGNING_DROP_DIR}"
echo "tree -f $SIGNING_DROP_DIR"
tree -f $SIGNING_DROP_DIR

# Copy artifacts to output
cd ${SOURCE_DIR}
cp $BUILD_X86_DROP_DIR/*.sh ${OUTPUT_DIR}/
cp $BUILD_X86_DROP_DIR/*.sha256sums ${OUTPUT_DIR}/
cp $SIGNING_DROP_DIR/build/buildoutput/omsagent*.asc ${OUTPUT_DIR}/


# Create VM extension zip package
source ${SOURCE_DIR}/omsagent.version
OMS_EXTENSION_VERSION="${OMS_BUILDVERSION_MAJOR}.${OMS_BUILDVERSION_MINOR}.${OMS_BUILDVERSION_PATCH}"
echo "Creating VM extension zip package for OMS ${OMS_EXTENSION_VERSION}"
cd ${SOURCE_DIR}/azure-linux-extensions/OmsAgent
./update_version.sh ${OMS_BUILDVERSION_MAJOR} ${OMS_BUILDVERSION_MINOR} ${OMS_BUILDVERSION_PATCH} ${OMS_BUILDVERSION_BUILDNR}
./apply_version.sh
./packaging.sh $OUTPUT_DIR $OUTPUT_DIR

# Create Ev2 artifacts
echo "Creating Ev2 artifacts"
cd ${SOURCE_DIR}
pwsh ${SOURCE_DIR}/ev2/EV2VMExtnPackager.ps1 -outputDir ${OUTPUT_DIR}/ -ExtensionInfoFile ${SOURCE_DIR}/ev2/extension-info.xml -BuildVersion ${OMS_EXTENSION_VERSION} -UseBuildVersionForExtnVersion -ReplaceBuildVersionInFileName

mv oms*.zip ${OUTPUT_DIR}/ServiceGroupRoot/

ls -la ${OUTPUT_DIR}/
tree -f ${OUTPUT_DIR}/

# Check exit code and exit with it if it is non-zero so that build will fail
EX=$?
if [ "$EX" -ne "0"  ]; then
  popd
  echo "Packaging Failed, exited with Exit Code $EX".
  exit $EX
fi

echo Packaging successed.
# Restore working directory
popd

# Exit with explicit 0 exit code so build will not fail
exit $EX
