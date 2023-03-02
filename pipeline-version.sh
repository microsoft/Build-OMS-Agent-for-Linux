#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/omsagent.version
BUILD_VERSION="${OMS_BUILDVERSION_MAJOR}.${OMS_BUILDVERSION_MINOR}.${OMS_BUILDVERSION_PATCH}-${OMS_BUILDVERSION_BUILDNR}_${CDP_DEFINITION_BUILD_COUNT}"

echo "##vso[build.updatebuildnumber]$BUILD_VERSION"
echo "##vso[task.setvariable variable=CUSTOM_VERSION;]$BUILD_VERSION"

exit 0