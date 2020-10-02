#!/bin/bash

# Requirements: Install Powershell command line in Ubuntu
# wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
# sudo dpkg -i packages-microsoft-prod.deb
# sudo apt-get update
# sudo add-apt-repository universe
# sudo apt-get install -y powershell
mkdir -p /tmp/ev2-tests
rm -rf /tmp/ev2-tests/*
pwsh EV2VMExtnPackager.ps1 -outputDir /tmp/ev2-tests/ -ExtensionInfoFile ExtensionInfo.xml -BuildVersion 1.1.1 -UseBuildVersionForExtnVersion -ReplaceBuildVersionInFileName
