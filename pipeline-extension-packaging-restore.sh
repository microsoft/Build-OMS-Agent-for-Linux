#!/bin/bash
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"
echo "Start of Restore "
echo "***************************************************************************"
echo "***************************************************************************"
echo "***************************************************************************"

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "ls -la $SOURCE_DIR"
ls -la $SOURCE_DIR

sudo apt install -y tree

echo Install Powershell package
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo add-apt-repository universe
sudo apt-get install -y powershell
pwsh --version


echo Cloning azure-linux-extensions ...
git clone --recursive https://github.com/Azure/azure-linux-extensions.git $SOURCE_DIR/azure-linux-extensions
cd $SOURCE_DIR/azure-linux-extensions
git checkout OMSAgent_v1.17.0
git submodule update --init --recursive
