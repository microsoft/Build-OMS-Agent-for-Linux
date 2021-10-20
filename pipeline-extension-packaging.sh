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

ls -la ${SOURCE_DIR}

ROOT_DROP_DIR="${SOURCE_DIR}/drop"
# ROOT_DROP_DIR="${CDP_TEMP_PRIOR_DROP_FOLDER_CONTAINER_PATH}/current/drop"
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
cp $BUILD_X86_DROP_DIR/*.universal.x64.sh ${OUTPUT_DIR}/
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

mkdir -p ${OUTPUT_DIR}/ev2/ARM
mkdir -p ${OUTPUT_DIR}/ev2/RDFE

echo "Creating Ev2 artifacts for ARM-based publishing"
pwsh ${SOURCE_DIR}/ev2/EV2ArtifactsGenerator.ps1 -outputDir ${OUTPUT_DIR}/ev2/ARM -ExtensionInfoFile ${SOURCE_DIR}/ev2/ExtensionInfo_ARM.xml -PackageFile ${OUTPUT_DIR}/oms${OMS_EXTENSION_VERSION}.zip -BuildVersion ${OMS_EXTENSION_VERSION} -UseBuildVersionForExtnVersion

EX=$?
if [ "$EX" -ne "0" ]; then
  popd
  echo "Command 'pwsh ${SOURCE_DIR}/ev2/EV2ArtifactsGenerator.ps1 ...' failed with exit code $EX."
  exit $EX
fi

echo "Creating Ev2 artifacts for RDFE-based publishing"
pwsh ${SOURCE_DIR}/ev2/EV2VMExtnPackager.ps1 -outputDir ${OUTPUT_DIR}/ev2/RDFE -ExtensionInfoFile ${SOURCE_DIR}/ev2/ExtensionInfo_RDFE.xml -BuildVersion ${OMS_EXTENSION_VERSION} -UseBuildVersionForExtnVersion -ReplaceBuildVersionInFileName

EX=$?
if [ "$EX" -ne "0" ]; then
  popd
  echo "Command 'pwsh ${SOURCE_DIR}/ev2/EV2VMExtnPackager.ps1 ...' failed with exit code $EX."
  exit $EX
fi

# Move extension zip to Ev2 folder
# Only necessary for EV2VMExtnPackager; EV2ArtifactsGenerator takes the .zip path as a param and places it in ServiceGroupRoot
mv ${OUTPUT_DIR}/oms${OMS_EXTENSION_VERSION}.zip ${OUTPUT_DIR}/ev2/RDFE/ServiceGroupRoot/

tree -f ${OUTPUT_DIR}/

# Check exit code and exit with it if it is non-zero so that build will fail
EX=$?
if [ "$EX" -ne "0" ]; then
  popd
  echo "Packaging failed with exit code $EX."
  exit $EX
fi

echo Packaging successed.
# Restore working directory
popd

# Exit with explicit 0 exit code so build will not fail
exit $EX
