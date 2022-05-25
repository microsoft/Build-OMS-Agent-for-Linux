<#
.SYNOPSIS
    Generate the artifacts required for EV2 deployment for all environments for publishing VM Extensions in CAPS
    Version: 1.0.1
#>
param(
    [Parameter(Mandatory=$True, HelpMessage="Output directory where ServiceGroupRoot is created.")]
    [string]$outputDir,

    [parameter(mandatory=$True, HelpMessage="The extension info filename with full path.")]
    [ValidateScript({Test-Path $_})]
    [string] $ExtensionInfoFile,

    [parameter(mandatory=$True, HelpMessage="The extension package filename with full path.")]
    [string] $PackageFile,

    [parameter(mandatory=$False, HelpMessage="The version of the build.")]
    [string] $BuildVersion,

    [parameter(mandatory=$False, HelpMessage="True, if build version must be used as the VM extension version as well.")]
    [switch] $UseBuildVersionForExtnVersion
)

<#
.SYNOPSIS
    Create the folder, if it does not exist
#>
function Create-DeploymentFolder([string] $rootPath, [string] $subdirectory)
{
    [string]$path = Join-Path -Path $rootPath -ChildPath $subdirectory;

    if(!(Test-Path -Path $path))
    {
        $directory = New-Item -Path $path -ItemType directory -Force;
    }

    return $path;
}

<#
.SYNOPSIS
    Create BuildVer.txt file with the given build version or defaults it to "1.0.0.0"
#>
function Create-BuildVersionFile([string] $buildVersion)
{
    if(!$BuildVersion)
    {
        $BuildVersion = "1.0.0.0"
    }

    $buildVersionFile = Join-Path -Path $ServiceGroupRoot -ChildPath $BuildVersionFileName
    $BuildVersion | Out-File $buildVersionFile -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates and returns ServiceResourceGroupDefinitions used in ServiceModel.json
#>
function Get-ServiceResourceGroupDefinitions
{
    $ServiceResourceGroupDefinition = [ordered]@{
        "Name" = $ServiceResourceGroupDefinitionName
        "ServiceResourceDefinitions" = @(
            [ordered]@{
                "Name" = $ExtRegResourceDefinitionName
                "composedOf" = @{
                    "arm" = @{
                        "templatePath" = "Templates\$RegisterExtensionArmTemplateFilename"
                    }
                }
            },

            [ordered]@{
                "Name" = $ExtPubResourceDefinitionName
                "composedOf" = @{
                    "arm" = @{
                        "templatePath" = "Templates\$PublishExtensionArmTemplateFilename"
                    }
                }
            }

            [ordered]@{
                "Name" = $ExtSetVisibilityResourceDefinitionName
                "composedOf" = @{
                    "arm" = @{
                        "templatePath" = "Templates\$SetExtensionVisibilityArmTemplateFilename"
                    }
                }
            }
        )
    }

    return ,@($ServiceResourceGroupDefinition)
}

<#
.SYNOPSIS
    Creates and returns the resources group for publishing extension
    This includes resources for registring an extension and publishing its version.
#>
function Get-PublishingResourceGroup
{
    [CmdletBinding()]
    param(
        [string] $CloudName
        )

    $ServiceResources = @()

    $RegisterExtensionResource = [ordered]@{
        "Name" = $ExtensionRegisteringResourceName
        "InstanceOf" = $ExtRegResourceDefinitionName
        "ArmParametersPath" = "Parameters\$($CloudName)_$RegisterExtensionArmParametersFilename"
    }

    $SetExternalExtensionResource = [ordered]@{
        "Name" = $SetExternalResourceName
        "InstanceOf" = $ExtSetVisibilityResourceDefinitionName
        "ArmParametersPath" = "Parameters\$($CloudName)_$SetExternalExtensionArmParametersFilename"
        "RolloutParametersPath" = "Parameters\$($CloudName)_$PublishExtensionRolloutParametersFilename"
    }

    $SetInternalExtensionResource = [ordered]@{
        "Name" = $SetInternalResourceName
        "InstanceOf" = $ExtSetVisibilityResourceDefinitionName
        "ArmParametersPath" = "Parameters\$($CloudName)_$SetInternalExtensionArmParametersFilename"
        "RolloutParametersPath" = "Parameters\$($CloudName)_$PublishExtensionRolloutParametersFilename"
    }

    $ServiceResources += $RegisterExtensionResource
    $ServiceResources += $SetExternalExtensionResource
    $ServiceResources += $SetInternalExtensionResource

    $Stages = $ExtensionInfoXmlContent.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions.Childnodes | Where-Object {$_.NodeType -eq "Element"}

    # Generate ServiceResource for each stage if present
    foreach ($Stage in $Stages)
    {
        $StageName = $Stage.Name
        $ServiceResource = [ordered]@{
            "Name" = $ExtensionPublishingResourceName + "-" + $($StageName)
            "InstanceOf" = $ExtPubResourceDefinitionName
            "ArmParametersPath" = "Parameters\$($CloudName)_$($StageName)_$PublishExtensionArmParametersFilename"
            "RolloutParametersPath" = "Parameters\$($CloudName)_$PublishExtensionRolloutParametersFilename"
        }

        $ServiceResources += $ServiceResource
    }

    # Generate ServiceResource for the all regions stage
    $ServiceResource = [ordered]@{
        "Name" = $ExtensionPublishingResourceName + "-" + $($AllRegionsStageName)
        "InstanceOf" = $ExtPubResourceDefinitionName
        "ArmParametersPath" = "Parameters\$($CloudName)_$($AllRegionsStageName)_$PublishExtensionArmParametersFilename"
        "RolloutParametersPath" = "Parameters\$($CloudName)_$PublishExtensionRolloutParametersFilename"
    }

    $ServiceResources += $ServiceResource

    $PublishingResourceGroup = [ordered]@{
        "AzureResourceGroupName" = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureResourceGroupName
        "Location" = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureLocation
        "InstanceOf" = $ServiceResourceGroupDefinitionName
        "AzureSubscriptionId" = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SubscriptionId
        "ServiceResources" = $ServiceResources
    }

    return $PublishingResourceGroup
}

<#
.SYNOPSIS
    Returns the resource manager URL for the given cloud name.
#>
function Get-ResourceManagerUrl
{
    [CmdletBinding()]
    param(
        [string] $CloudName
        )

    # Return the default region
    switch ($CloudName)
    {
        'Public'
        {
            return "https://management.azure.com"
        }
        'Fairfax'
        {
            return "https://management.usgovcloudapi.net"
        }
        'Mooncake'
        {
            return "https://management.chinacloudapi.cn"
        }
        'Blackforest'
        {
            return "https://management.microsoftazure.de"
        }
        'USNat'
        {
            return "https://management.azure.eaglex.ic.gov"
        }
        'USSec'
        {
            return "https://management.azure.microsoft.scloud"
        }
        default
        {
            ThrowAndExit -ErrorMessage "CloudTypes supported at this time are Public, Blackforest, Mooncake, Fairfax, USSec and USNat. '$($CloudName)' is not supported."
        }
    }
}

<#
.SYNOPSIS
    Creates and returns ServiceResourceGroups used in ServiceModel.json
#>
function Get-ServiceResourceGroups
{
    [CmdletBinding()]
    param(
        [string] $CloudName
        )

    $ServiceResourceGroups = @()
    $ServiceResourceGroups += Get-PublishingResourceGroup -CloudName $CloudName

    return ,$ServiceResourceGroups
}

<#
.SYNOPSIS
    Creates the ServiceModel.json for the given cloud
#>
function Create-ServiceModel
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ServiceModel = [ordered]@{
        '$schema' = 'https://ev2schema.azure.net/schemas/2020-01-01/serviceModel.json'
        'contentVersion' = '1.0.0.0'

        "ServiceMetadata" = [ordered]@{
            "ServiceGroup" = "VMExtension"
            "Environment" = $CloudName
        }

        "ServiceResourceGroupDefinitions" = Get-ServiceResourceGroupDefinitions
        "ServiceResourceGroups" = Get-ServiceResourceGroups -CloudName $CloudName
    }

    $ServieModelFilename = Join-Path -Path $ServiceGroupRoot -ChildPath "$($CloudName)_ServiceModel.json"
    $ServiceModel | ConvertTo-Json -Depth 30 | out-file $ServieModelFilename -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates and returns RolloutMetadata that is used in all the RolloutSpec files
#>
function Get-RolloutMetadata
{
    $RolloutMetadata = [ordered]@{
        "Name" = "VM Extension publishing"
        "ServiceModelPath" = "$($CloudName)_ServiceModel.json"
        "RolloutType" = "Hotfix"
        "BuildSource" = [ordered]@{
            "Parameters" = [ordered]@{
                "ServiceGroupRoot" = "ServiceGroupRoot"
                "VersionFile" = $BuildVersionFileName
            }
        }
    }

    return $RolloutMetadata
}

<#
.SYNOPSIS
    Creates the RolloutSpec json file for registering the extension type
#>
function Create-RolloutSpec-RegisterExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $RolloutSpec = [ordered]@{
        '$schema' = "https://ev2schema.azure.net/schemas/2020-01-01/rolloutSpecification.json"
        "contentVersion" = "1.0.0.0"
        "RolloutMetadata" = Get-RolloutMetadata
        "OrchestratedSteps" = @(
            [ordered]@{
                "Name" = "RegisterVMExtension"
                "TargetType" = "ServiceResource"
                "TargetName" = $ExtensionRegisteringResourceName
                "Actions" = @("Deploy")
            }
        )
    }

    # Create the rollout spec file
    $RolloutSpecFilename = Join-Path -Path $ServiceGroupRoot -ChildPath "$($CloudName + "_" + $RegisterExtensionRolloutSpecFilename)"
    $RolloutSpec | ConvertTo-Json -Depth 30 | out-file $RolloutSpecFilename -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates the RolloutSpec json file for publishing an extension version
#>
function Create-RolloutSpec-PublishExtension
{
    [CmdletBinding()]
    param(
        [string] $StageName
        )

    $TargetName = $ExtensionPublishingResourceName + "-" + $($StageName)
    $RolloutSpecFilename = "$($CloudName + "_" + $($StageName) + "_" + $PublishExtensionRolloutSpecFilename)"

    $PublishExtensionStepName = "PublishVMExtension"
    $RolloutSpec = [ordered]@{
        '$schema' = "https://ev2schema.azure.net/schemas/2020-01-01/rolloutSpecification.json"
        "contentVersion" = "1.0.0.0"
        "RolloutMetadata" = Get-RolloutMetadata
        "OrchestratedSteps" = @(
            [ordered]@{
                "Name" = $PublishExtensionStepName
                "TargetType" = "ServiceResource"
                "TargetName" = $TargetName
                "Actions" = @("Deploy", "restHealthCheck/$TerminalStatusCheckName", "restHealthCheck/$CompletionStatusCheckName")
            }
        )
    }

    # Create the rollout spec file
    $RolloutSpecFilename = Join-Path -Path $ServiceGroupRoot -ChildPath "$($CloudName + "_" + $($StageName) + "_" + $PublishExtensionRolloutSpecFilename)"
    $RolloutSpec | ConvertTo-Json -Depth 30 | out-file $RolloutSpecFilename -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates the RolloutSpec json file for publishing an extension version
    based on the SDPRegions defined.
#>
function Create-RolloutSpecs-PublishExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $Stages = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions.Childnodes | Where-Object {$_.NodeType -eq "Element"}

    # Create rollout spec for each stage of regions, if present
    foreach ($Stage in $Stages)
    {
        Create-RolloutSpec-PublishExtension -StageName $Stage.Name
    }

    # Create rollout spec for all-regions stage
    Create-RolloutSpec-PublishExtension -StageName $AllRegionsStageName
}

<#
.SYNOPSIS
    Creates the RolloutSpec json file for setting external extension
#>
function Create-RolloutSpec-SetExternalExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $RolloutSpec = [ordered]@{
        '$schema' = "https://ev2schema.azure.net/schemas/2020-01-01/rolloutSpecification.json"
        "contentVersion" = "1.0.0.0"
        "RolloutMetadata" = Get-RolloutMetadata
        "OrchestratedSteps" = @(
            [ordered]@{
                "Name" = "SetExternalExtension"
                "TargetType" = "ServiceResource"
                "TargetName" = $SetExternalResourceName
                "Actions" = @("Deploy", "restHealthCheck/$TerminalStatusCheckName", "restHealthCheck/$CompletionStatusCheckName")
            }
        )
    }

    # Create the rollout spec file
    $RolloutSpecFilename = Join-Path -Path $ServiceGroupRoot -ChildPath "$($CloudName + "_" + $SetExternalExtensionRolloutSpecFilename)"
    $RolloutSpec | ConvertTo-Json -Depth 30 | out-file $RolloutSpecFilename -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates the RolloutSpec json file for setting internal extension
#>
function Create-RolloutSpec-SetInternalExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $RolloutSpec = [ordered]@{
        '$schema' = "https://ev2schema.azure.net/schemas/2020-01-01/rolloutSpecification.json"
        "contentVersion" = "1.0.0.0"
        "RolloutMetadata" = Get-RolloutMetadata
        "OrchestratedSteps" = @(
            [ordered]@{
                "Name" = "SetInternalExtension"
                "TargetType" = "ServiceResource"
                "TargetName" = $SetInternalResourceName
                "Actions" = @("Deploy", "restHealthCheck/$TerminalStatusCheckName", "restHealthCheck/$CompletionStatusCheckName")
            }
        )
    }

    # Create the rollout spec file
    $RolloutSpecFilename = Join-Path -Path $ServiceGroupRoot -ChildPath "$($CloudName + "_" + $SetInternalExtensionRolloutSpecFilename)"
    $RolloutSpec | ConvertTo-Json -Depth 30 | out-file $RolloutSpecFilename -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Reads ExtensionConfiguration data from the ExtensionInfo xml file
#>
function Get-ExtensionConfiguration
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml
        )

    $ExtensionConfiguration = $null
    if ($ExtnInfoXml.ExtensionInfo.ExtensionImage.IsJsonExtension -or `
        $ExtnInfoXml.ExtensionInfo.ExtensionImage.PublicConfigurationSchema -or `
        $ExtnInfoXml.ExtensionInfo.ExtensionImage.PrivateConfigurationSchema -or `
        $ExtnInfoXml.ExtensionInfo.ExtensionImage.SampleConfig)
    {
        $ExtensionConfiguration = [ordered]@{
            "isJsonExtension" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.IsJsonExtension
            "publicConfigurationSchema" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.PublicConfigurationSchema
            "privateConfigurationSchema" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.PrivateConfigurationSchema
            "sampleConfig" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.SampleConfig
        }
    }

    return $ExtensionConfiguration
}

<#
.SYNOPSIS
    Reads ExtensionCertificate data from the ExtensionInfo xml file
#>
function Get-ExtensionCertificate
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml
        )

    $ExtensionCertificate = $null
    if ($ExtnInfoXml.ExtensionInfo.ExtensionImage.Certificate)
    {
        $ExtensionCertificate = [ordered]@{
            "storeLocation" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Certificate.StoreLocation
            "storeName" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Certificate.StoreName
            "thumbprintAlgorithm" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Certificate.ThumbprintAlgorithm
            "thumbprintRequired" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Certificate.ThumbprintRequired
        }
    }

    return $ExtensionCertificate
}

<#
.SYNOPSIS
    Reads the list of ExtensionEndpoints data from the ExtensionInfo xml file
#>
function Get-ExtensionEndPoints
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml
        )

    $ExtensionEndpoints = $null
    $Endpoints = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Endpoints
    if ($Endpoints)
    {
        $InputEndpointsList = $Endpoints.InputEndpoints.Childnodes | Where-Object {$_.NodeType -eq "Element"}
        $InternalEndpointsList = $Endpoints.InternalEndpoints.Childnodes | Where-Object {$_.NodeType -eq "Element"}
        $InstanceInputEndpointsList = $Endpoints.InstanceInputEndpoints.Childnodes | Where-Object {$_.NodeType -eq "Element"}

        $InputEndpoints = @()
        foreach($Endpoint in $InputEndpointsList)
        {
            $InputEndpoints += [ordered]@{
                "name" = $Endpoint.Name
                "protocol" = $Endpoint.Protocol
                "port" = $Endpoint.Port
                "localPort" = $Endpoint.LocalPort
            }
        }

        $InternalEndpoints = @()
        foreach($Endpoint in $InternalEndpointsList)
        {
            $InternalEndpoints += [ordered]@{
                "name" = $Endpoint.Name
                "protocol" = $Endpoint.Protocol
                "port" = $Endpoint.Port
            }
        }

        $InstanceInputEndpoints = @()
        foreach($Endpoint in $InstanceInputEndpointsList)
        {
            $InstanceInputEndpoints += [ordered]@{
                "name" = $Endpoint.Name
                "protocol" = $Endpoint.Protocol
                "localPort" = $Endpoint.LocalPort
                "fixedPortMin" = $Endpoint.FixedPortMin
                "fixedPortMax" = $Endpoint.FixedPortMax
            }
        }

        $ExtensionEndpoints = [ordered]@{}
        if ($InputEndpointsList -or $InternalEndpointsList -or $InstanceInputEndpointsList)
        {
            $ExtensionEndpoints = [ordered]@{
                "inputEndpoints" = If ($InputEndpoints.Count -gt 0) {,$InputEndpoints} Else {$null}
                "internalEndpoints" = If ($InternalEndpoints.Count -gt 0) {,$InternalEndpoints} Else {$null}
                "instanceInputEndpoints" = If ($InstanceInputEndpoints.Count -gt 0) {,$InstanceInputEndpoints} Else {$null}
            }
        }
    }

    return $ExtensionEndpoints
}

<#
.SYNOPSIS
    Reads the list of ExtensionLocalResources data from the ExtensionInfo xml file
#>
function Get-ExtensionLocalResources
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml
        )

    $ExtensionLocalResources = $null
    if ($ExtnInfoXml.ExtensionInfo.ExtensionImage.LocalResources)
    {
        $ExtensionLocalResources = @()
        $ExtensionLocalResourcesList = $ExtnInfoXml.ExtensionInfo.ExtensionImage.LocalResources.Childnodes | Where-Object {$_.NodeType -eq "Element"}
        foreach($LocalResource in $ExtensionLocalResourcesList)
        {
            $ExtensionLocalResources += [ordered]@{
                "name" = $LocalResource.Name
                "sizeInMB" = $LocalResource.SizeInMB
            }
        }
    }

    return ,$ExtensionLocalResources
}

<#
.SYNOPSIS
    Creates ARM template file for creating SharedVMExtension resource that registers the extension type
#>
function Create-ArmTemplateFile-RegisterExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ArmTemplate = [ordered]@{
        '$schema'= "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion"= "1.0.0.0"
        "parameters"= [ordered]@{
            "location"= [ordered]@{
                "type"= "string"
                "defaultValue"= "[resourceGroup().location]"
                "metadata"= [ordered]@{
                    "description"= "Location for all resources."
                }
            }
        }
        "variables"= [ordered]@{
            "publisherName"= $PublisherName
            "typeName"= $ExtensionTypeName
        }
        "resources"= @(
            [ordered]@{
                "type"= "Microsoft.Compute/sharedVMExtensions"
                "name"= "[concat(variables('publisherName'), '.', variables('typeName'))]"
                "apiVersion"= $ApiVersion
                "location"= "[parameters('location')]"
                "properties"= [ordered]@{
                    "identifier"= [ordered]@{
                        "publisher"= "[variables('publisherName')]"
                        "type"= "[variables('typeName')]"
                    }
                    "label"= $ExtnInfoXml.ExtensionInfo.ExtensionImage.Label
                    "description"= $ExtnInfoXml.ExtensionInfo.ExtensionImage.Description
                    "companyName"= $ExtnInfoXml.ExtensionInfo.ExtensionImage.CompanyName
                }
            }
        )
    }

    $ArmTemplateFilenameWithPath = Join-Path -Path $Template_path -ChildPath $RegisterExtensionArmTemplateFilename
    $ArmTemplate | ConvertTo-Json -Depth 30 | % {$_.replace("\u0027","'")} | out-file $ArmTemplateFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates ARM template file for creating SharedVMExtensionVersion resource that publishes the extension version
#>
function Create-ArmTemplateFile-PublishExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ArmTemplate = [ordered]@{
        '$schema'= "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion"= "1.0.0.0"
        "parameters"= [ordered]@{
            "location"= [ordered]@{
                "type"= "string"
                "defaultValue"= "[resourceGroup().location]"
                "metadata"= [ordered]@{
                    "description"= "Location for all resources."
                }
            }
            "packageUri"= [ordered]@{
                "type"= "securestring"
                "defaultValue" = ""
                "metadata"= [ordered]@{
                    "description"= "The path to the package that contains the extension to publish."
                }
            }
            "regions" = [ordered]@{
                "type" = "array"
                "defaultValue" = @()
                "metadata"=  @{
                    "description" = "The list of regions to publish the extension."
                }
            }
            "isInternalExtension" = [ordered]@{
                "type"= "string"
                "defaultValue"= ""
                "metadata"= [ordered]@{
                    "description"= "Flag to determine if the extension is internal or public."
                }
            }
        }
        "variables"= [ordered]@{
            "publisherName"= $PublisherName
            "typeName"= $ExtensionTypeName
            "version"= $ExtensionVersion
        }
        "resources"= @(
            [ordered]@{
                "type"= "Microsoft.Compute/sharedVMExtensions/versions"
                "name"= "[concat(variables('publisherName'), '.', variables('typeName'), '/', variables('version'))]"
                "apiVersion"= $ApiVersion
                "location"= "[parameters('location')]"
                "properties"= [ordered]@{
                    "mediaLink"= "[parameters('packageUri')]"
                    "regions"= "[parameters('regions')]"
                    "computeRole"= $ComputeRole
                    "supportedOS"= $ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS
                    "isInternalExtension"= "[parameters('isInternalExtension')]"
                    "safeDeploymentPolicy"= If ($null -eq $ExtnInfoXml.ExtensionInfo.ExtensionImage.SafeDeploymentPolicy) {"Minimal"} Else {$ExtnInfoXml.ExtensionInfo.ExtensionImage.SafeDeploymentPolicy}
                    "supportsMultipleExtensions" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportsMultipleExtensions
                    "disallowMajorVersionUpgrade" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.DisallowMajorVersionUpgrade
                    "rollbackSupported" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.RollbackSupported
                    "blockRoleUponFailure" = $ExtnInfoXml.ExtensionInfo.ExtensionImage.BlockRoleUponFailure
                    "configuration" = Get-ExtensionConfiguration -ExtnInfoXml $ExtnInfoXml
                    "certificate" = Get-ExtensionCertificate -ExtnInfoXml $ExtnInfoXml
                    "endpoints" = Get-ExtensionEndpoints -ExtnInfoXml $ExtnInfoXml
                    "localResources" = Get-ExtensionLocalResources -ExtnInfoXml $ExtnInfoXml
                }
            }
        )
    }

    $ArmTemplateFilenameWithPath = Join-Path -Path $Template_path -ChildPath $PublishExtensionArmTemplateFilename
    $ArmTemplate | ConvertTo-Json -Depth 30 | % {$_.replace("\u0027","'")} | out-file $ArmTemplateFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates ARM template file for setting SharedVMExtensionVersion resource to be internal or external
#>
function Create-ArmTemplateFile-SetExtensionVisibility
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ArmTemplate = [ordered]@{
        '$schema'= "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion"= "1.0.0.0"
        "parameters"= [ordered]@{
            "location"= [ordered]@{
                "type"= "string"
                "defaultValue"= "[resourceGroup().location]"
                "metadata"= [ordered]@{
                    "description"= "Location for all resources."
                }
            }
            "isInternalExtension" = [ordered]@{
                "type"= "string"
                "defaultValue"= ""
                "metadata"= [ordered]@{
                    "description"= "Flag to determine if the extension is internal or external (public)."
                }
            }
        }
        "variables"= [ordered]@{
            "publisherName"= $PublisherName
            "typeName"= $ExtensionTypeName
            "version"= $ExtensionVersion
        }
        "resources"= @(
            [ordered]@{
                "type"= "Microsoft.Compute/sharedVMExtensions/versions"
                "name"= "[concat(variables('publisherName'), '.', variables('typeName'), '/', variables('version'))]"
                "apiVersion"= $ApiVersion
                "location"= "[parameters('location')]"
                "properties"= [ordered]@{
                    "isInternalExtension"= "[parameters('isInternalExtension')]"
                }
            }
        )
    }

    $ArmTemplateFilenameWithPath = Join-Path -Path $Template_path -ChildPath $SetExtensionVisibilityArmTemplateFilename
    $ArmTemplate | ConvertTo-Json -Depth 30 | % {$_.replace("\u0027","'")} | out-file $ArmTemplateFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates ARM template parameter file for registering extension type
#>
function Create-ArmParametersFile-RegisterExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ArmParameters = [ordered]@{
        '$schema' = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion" = "1.0.0.0"
        "parameters" = [ordered]@{
        }
    }

    $ArmParametersFilenameWithPath = Join-Path -Path $Param_path -ChildPath $($CloudName + "_" + $RegisterExtensionArmParametersFilename)
    $ArmParameters | ConvertTo-Json -Depth 30 | out-file $ArmParametersFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates ARM template parameter file(s) for publishing extension version in each stage in SDPRegions
#>
function Create-ArmParametersFile-PublishExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $Regions = @()

    $ArmParameters = [ordered]@{
        '$schema' = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion" = "1.0.0.0"
        "paths" = @([ordered]@{"parameterReference" = "packageUri"})
        "parameters" = [ordered]@{
            "packageUri" = @{
                "value" = Split-Path $PackageFile -leaf
            }
            "regions" = [ref]$Regions
            "isInternalExtension" = [ref]$ExtnInfoXml.ExtensionInfo.ExtensionImage.IsInternalExtension
        }
    }

    $Stages = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions.Childnodes | Where-Object {$_.NodeType -eq "Element"}

    # Create ARM template parameter files for each stage of regions, if present
    foreach ($Stage in $Stages)
    {
        $Regions = @($Stage.'#text' | % {$_.replace(";", ",")} | % {$_.split(",")})

        $ArmParametersFilenameWithPath = Join-Path -Path $Param_path -ChildPath $($CloudName + "_" + $Stage.Name + "_" + $PublishExtensionArmParametersFilename)
        $ArmParameters | ConvertTo-Json -Depth 30 | out-file $ArmParametersFilenameWithPath -Encoding utf8 -Force

        # Remove the paths, packageUri and isInternalExtension parameters for stages other than the first one
        $ArmParameters.Remove("paths")
        $ArmParameters.parameters.Remove("packageUri")
        $ArmParameters.parameters.Remove("isInternalExtension")
    }

    # Create ARM tempalte parameter file for all-regions stage
    $Regions = @("*")
    $ArmParametersFilenameWithPath = Join-Path -Path $Param_path -ChildPath $($CloudName + "_" + $AllRegionsStageName + "_" + $PublishExtensionArmParametersFilename)
    $ArmParameters | ConvertTo-Json -Depth 30 | out-file $ArmParametersFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates ARM template parameter file for publishing extension version as external
#>
function Create-ArmParametersFile-SetExternalExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ArmParameters = [ordered]@{
        '$schema' = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion" = "1.0.0.0"
        "parameters" = [ordered]@{
            "isInternalExtension" = [ref]($false.ToString())
        }
    }

    $ArmParametersFilenameWithPath = Join-Path -Path $Param_path -ChildPath $($CloudName + "_" + $SetExternalExtensionArmParametersFilename)
    $ArmParameters | ConvertTo-Json -Depth 30 | out-file $ArmParametersFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates ARM template parameter file for publishing extension version as internal
#>
function Create-ArmParametersFile-SetInternalExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $ArmParameters = [ordered]@{
        '$schema' = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
        "contentVersion" = "1.0.0.0"
        "parameters" = [ordered]@{
            "isInternalExtension" = [ref]($true.ToString())
        }
    }

    $ArmParametersFilenameWithPath = Join-Path -Path $Param_path -ChildPath $($CloudName + "_" + $SetInternalExtensionArmParametersFilename)
    $ArmParameters | ConvertTo-Json -Depth 30 | out-file $ArmParametersFilenameWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Creates Rollout parameter file for polling extension replication status
#>
function Create-RolloutParametersFile-PublishExtension
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    $BaseUri = Get-ResourceManagerUrl -CloudName $CloudName
    $SubscriptionId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SubscriptionId
    $ResourceGroup = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureResourceGroupName
    $StatusCheckUri = "$BaseUri/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/sharedVMExtensions/$PublisherName.$ExtensionTypeName/versions/$ExtensionVersion$('?api-version')=$ApiVersion"

    $httpRequest = [ordered]@{
        "method" = "Get"
        "uri" = $StatusCheckUri
        "authentication" = [ordered]@{
            "type" = "RolloutIdentity"
        }
    }

    $RolloutParameters = [ordered]@{}
    $RolloutParameters.Add('$schema','https://ev2schema.azure.net/schemas/2020-01-01/rolloutParameters.json')
    $RolloutParameters.Add('contentVersion','1.0.0.0')

    $RestHealthChecks = @(
        [ordered]@{
            "name" = $TerminalStatusCheckName
            "waitDuration" = "PT1M"
            "maxElasticDuration" = "PT6H"
            "healthyStateDuration" = "PT1M"
            "healthChecks" = @([ordered]@{
                "name" = "ReplicationStatus"
                "request" = $httpRequest
                "response" = [ordered]@{
                    "successStatusCodes" = @("OK")
                    "regex" = [ordered]@{
                        "matchQuantifier" = "Any"
                        "matches" = @(
                            """aggregatedState"": ""Completed""",
                            """aggregatedState"": ""Failed"""
                        )
                    }
                }
            })
        },
        [ordered]@{
            "name" = $CompletionStatusCheckName
            "healthyStateDuration" = "PT1M"
            "healthChecks" = @([ordered]@{
                "name" = "ReplicationStatus"
                "request" = $httpRequest
                "response" = [ordered]@{
                    "successStatusCodes" = @("OK")
                    "regex" = [ordered]@{
                        "matchQuantifier" = "All"
                        "matches" = @(
                            """aggregatedState"": ""Completed""",
                            """provisioningState"": ""Succeeded"""
                        )
                    }
                }
            })
        }
    )

    $RolloutParameters.Add("restHealthChecks", $RestHealthChecks)

    $RolloutParametersFilename = Join-Path -Path $Param_path -ChildPath "$($CloudName + "_" + $PublishExtensionRolloutParametersFilename)"
    $RolloutParameters | ConvertTo-Json -Depth 30 | out-file $RolloutParametersFilename -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Function for creating ARM template files for registering and publishing extension
#>
function Create-ArmTemplateFiles
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    Create-ArmTemplateFile-RegisterExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-ArmTemplateFile-PublishExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-ArmTemplateFile-SetExtensionVisibility -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
}

<#
.SYNOPSIS
    Function for creating ARM template and Rollout parameter files
#>
function Create-ParametersFiles
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

    # Create ARM parameter files
    Create-ArmParametersFile-RegisterExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-ArmParametersFile-PublishExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-ArmParametersFile-SetExternalExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-ArmParametersFile-SetInternalExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent

    # Create Rollout parameter files
    Create-RolloutParametersFile-PublishExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
}

<#
.SYNOPSIS
    Helper function to throw an exception and exit
#>
function ThrowAndExit
{
    [CmdletBinding()]
    param(
        [string] $ErrorMessage
        )

    throw $ErrorMessage
    exit -1
}

<#
.SYNOPSIS
    Helper function to check if the input object is null or empty.
    If yes, throws an exception and exits
#>
function IfNullThrowAndExit
{
    [CmdletBinding()]
    param(
        $inputObject,
        [string] $ErrorMessage
        )

    if([string]::IsNullOrWhiteSpace($inputObject))
    {
        ThrowAndExit -ErrorMessage $ErrorMessage
    }
}

<#
.SYNOPSIS
    Reads ComputeRole value from ExtensionInfo section if exists.
    Otherwise maps the HostingResources value to the corresponding ComputeRole value.
    It is already validated that either ComputeRole or HostingResources but not both exist.
#>
function Get-ComputeRole
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml
        )

    if ($ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -ne $null)
    {
        return $ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole
    }

    # When ComputeRole is not present, map the HostingResources values to ComputeRole
    $hostingResources = $ExtnInfoXml.ExtensionInfo.ExtensionImage.HostingResources.Split('|') | ForEach-Object {$_.Trim()}
    $allRolesExist = $true

    foreach ($value in $ValidHostingResourcesValues)
    {
        if (!($value -in $hostingResources))
        {
            $allRolesExist = $false
            break
        }
    }

    # If the HostingResources contains all the valid values, maps it to ComputeRole=All
    if ($allRolesExist)
    {
        return $AllRoles
    }

    # If the HostingResources contains 'VmRole', maps it to ComputeRole=IaaS
    if ($VmRole -in $hostingResources)
    {
        return $IaaSRole
    }

    # Otherwise map it to ComputeRole=PaaS
    return $PaaSRole
}

<#
.SYNOPSIS
    Validate the ExtensionInfo xml file
#>
function Validate-ExtensionInfoFile
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml,
        $UseBuildVersionForExtnVersion
        )

    IfNullThrowAndExit -inputObject $ExtnInfoXml -ErrorMessage "xml file is null."
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo -ErrorMessage "ExtensionInfo node not found in XML."
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.ExtensionImage.ProviderNameSpace -ErrorMessage "Extension Namespace is null."
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.ExtensionImage.Type.Trim() -ErrorMessage "Extension Type is null."
    
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS.Trim() -ErrorMessage "Extension SupportedOS is null."
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.ExtensionImage.Label.Trim() -ErrorMessage "Extension Label is null."

    # Make sure either HostingResources or ComputeRole is present
    if (($ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -eq $null -and $ExtnInfoXml.ExtensionInfo.ExtensionImage.HostingResources -eq $null) -or
        ($ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -ne $null -and $ExtnInfoXml.ExtensionInfo.ExtensionImage.HostingResources -ne $null))
    {
        ThrowAndExit -ErrorMessage "Either ComputeRole or HostingResources but not both must be present"
    }

    # ComputeRole must be IaaS, PaaS or All only
    if($ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -ne $null -and
       !($ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -ieq "IaaS" -or `
         $ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -ieq "PaaS" -or `
         $ExtnInfoXml.ExtensionInfo.ExtensionImage.ComputeRole -ieq "All"))
    {
        ThrowAndExit -ErrorMessage "ComputeRole must be IaaS, PaaS or All only."
    }

    # HostringResources must be WebRole, WorkerRole, VmRole or combination of them.
    if($ExtnInfoXml.ExtensionInfo.ExtensionImage.HostingResources -ne $null)
    {
        $ExtnInfoXml.ExtensionInfo.ExtensionImage.HostingResources.Split('|') | ForEach-Object `
        {
            if (!($_.Trim() -in $ValidHostingResourcesValues))
            {
                ThrowAndExit -ErrorMessage "HostingResources contains invalid value [$_]. Valid values are ($validHostingResourcesValues)"
            }
        }
    }

    # SupportedOS must be Windows or Linux only
    if(!($ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS -ieq "Windows" -or $ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS -ieq "Linux"))
    {
        ThrowAndExit -ErrorMessage "SupportedOS must be Windows or Linux only."
    }

    # SafeDeploymentPolicy must be Standard, Minimal or Hotfix only
    if($ExtnInfoXml.ExtensionInfo.ExtensionImage.SafeDeploymentPolicy -ne $null -and
       !($ExtnInfoXml.ExtensionInfo.ExtensionImage.SafeDeploymentPolicy -ieq "Standard" -or `
         $ExtnInfoXml.ExtensionInfo.ExtensionImage.SafeDeploymentPolicy -ieq "Minimal" -or `
         $ExtnInfoXml.ExtensionInfo.ExtensionImage.SafeDeploymentPolicy -ieq "Hotfix"))
    {
        ThrowAndExit -ErrorMessage "SafeDeploymentPolicy must be Standard, Minimal or Hotfix only."
    }

    
    # MediaLink should be empty, no spaces
    if ($ExtnInfoXml.ExtensionInfo.ExtensionImage.MediaLink.Length -gt 0)
    {
        ThrowAndExit -ErrorMessage "MediaLink should be empty"
    }

    # if the switch $UseBuildVersionForExtnVersion is used, the build number must be used as extension number.
    # In this case, the extension version in ExtensionInfo xml should be empty
    if($UseBuildVersionForExtnVersion)
    {
        if (!$BuildVersion)
        {
            ThrowAndExit -ErrorMessage "BuildVersion cannot be null when UseBuildVersionForExtnVersion flag is set"
        }
        
        if ($ExtnInfoXml.ExtensionInfo.ExtensionImage.Version.Length -gt 0)
        {
            ThrowAndExit -ErrorMessage "The switch UseBuildVersionForExtnVersion is used. Version value in xml file should be empty!"
        }
    }
    else
    {
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.ExtensionImage.Version.Trim() -ErrorMessage "Extension Version is null."
    }

    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes -ErrorMessage "CloudTypes node not found."

    if($ExtnInfoXml.ExtensionInfo.CloudTypes.ChildNodes.Count -le 0)
    {
        ThrowAndExit -ErrorMessage "CloudTypes not specified. Check the ExtensionInfo file."
    }

    foreach ($CloudType in $ExtensionInfoXmlContent.ExtensionInfo.CloudTypes.ChildNodes)
    {
        $CloudName =  $CloudType.Name

        # Validate cloud name
        if(!($CloudName -ieq "Public" -or $CloudName -ieq "Blackforest" -or $CloudName -ieq "Mooncake" -or $CloudName -ieq "Fairfax" -or $CloudName -ieq "USSec" -or $CloudName -ieq "USNat"))
        {
            ThrowAndExit -ErrorMessage "CloudTypes supported at this time are Public, Blackforest, Mooncake, Fairfax, USSec and USNat Not '$($CloudName)'."
        }

        # Check for mandatory fields for each cloud
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SubscriptionId -ErrorMessage "SubscriptionId for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureLocation -ErrorMessage "AzureLocation for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureResourceGroupName -ErrorMessage "AzureResourceGroupName for Cloud $($CloudName) is not valid."

        # Additional check for AzureResourceGroupName for the publishers migrating to newer APIs, as it was set to "TBD" by default
        if ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureResourceGroupName -eq "TBD")
        {
            ThrowAndExit -ErrorMessage "AzureResourceGroupName for Cloud $($CloudName) is not valid. Please specify a valid resource group name."
        }

        # Validate each stage in SDPRegions
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions -ErrorMessage "SDPRegions for Cloud $($CloudName) is not valid."
        $SDPStageCount = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions | Select-Object -ExpandProperty childnodes | Where-Object {$_.name -like 'Stage*'}).Count
        if($SDPStageCount -lt 2)
        {
            # Some publishers only publish to 2 canary regions. Also, Some clouds like Blackforest, USNat has only 2 regions.
            ThrowAndExit -ErrorMessage "SDP is not being followed for $($CloudName). There must be 2 or more Stages in SDPRegions."
        }

        for($i=1; $i -lt $SDPStageCount; $i++)
        {
            $stageName = "Stage$($i)"
            $ExtnRegions = $($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions.$stageName)

            IfNullThrowAndExit -inputObject $ExtnRegions -ErrorMessage "Stage $($stageName) in $($CloudName) is not valid."

            $nextStage = "Stage$($i + 1)"
            $NextStageRegions = $($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions.$nextStage)
            IfNullThrowAndExit -inputObject $NextStageRegions -ErrorMessage "Stage $($nextStage) in $($CloudName) is not valid."

            if($NextStageRegions.Length -le $ExtnRegions.Length)
            {
                ThrowAndExit -ErrorMessage "Regions in $($nextStage) must be more than $($stageName) in Cloud '$($CloudName)'."
            }

            if($NextStageRegions -notmatch $ExtnRegions)
            {
                ThrowAndExit -ErrorMessage "Regions in $($nextStage) must include the regions in $($stageName) in Cloud '$($CloudName)'."
            }
        }
    }
}


# =================================================================================================
# Main execution 
# =================================================================================================

# Constants
$VmRole = "VmRole"
$WebRole = "WebRole"
$WorkerRole = "WorkerRole"
$IaaSRole = "IaaS"
$PaaSRole = "PaaS"
$AllRoles = "All"

$ValidHostingResourcesValues = @($VmRole, $WebRole, $WorkerRole)

# Read and validate the ExtensionInfo file
$ExtensionInfoXmlContent = [xml](Get-Content $ExtensionInfoFile -Encoding UTF8)
Validate-ExtensionInfoFile -ExtnInfoXml $ExtensionInfoXmlContent -UseBuildVersionForExtnVersion $UseBuildVersionForExtnVersion

$ComputeRole = Get-ComputeRole -ExtnInfoXml $ExtensionInfoXmlContent

$ApiVersion = "2019-12-01"
$ServiceResourceGroupDefinitionName = "ExtensionPublishing"
$ExtRegResourceDefinitionName = "ExtensionRegistering-Def"
$ExtPubResourceDefinitionName = "ExtensionPublishing-Def"
$ExtSetVisibilityResourceDefinitionName = "ExtensionSetVisibility-Def"

$ExtensionRegisteringResourceName = "RegisterExtensionResource"
$ExtensionPublishingResourceName = "PublishExtensionResource"
$SetExternalResourceName = "SetExternalResource"
$SetInternalResourceName = "SetInternalResource"

$TerminalStatusCheckName = "TerminalStatusCheck"
$CompletionStatusCheckName = "CompletionStatusCheck"

$BuildVersionFileName = "BuildVer.txt"
$RegisterExtensionArmTemplateFilename = "SharedVMExtensionResource.json"
$RegisterExtensionRolloutSpecFilename = "RolloutSpec_RegisterExtension.json"
$RegisterExtensionArmParametersFilename = "ArmParameters_RegisterExtension.json"

$PublishExtensionArmTemplateFilename = "SharedVMExtensionVersionResource.json"
$PublishExtensionRolloutSpecFilename = "RolloutSpec_PublishExtension.json"
$PublishExtensionArmParametersFilename = "ArmParameters_PublishExtension.json"
$PublishExtensionRolloutParametersFilename = "RolloutParameters_PublishExtension.json"

$SetExtensionVisibilityArmTemplateFilename = "SetExtensionVersionVisibility.json"

$SetExternalExtensionRolloutSpecFilename = "RolloutSpec_SetExternalExtension.json"
$SetExternalExtensionArmParametersFilename = "ArmParameters_SetExternalExtension.json"
$SetInternalExtensionRolloutSpecFilename = "RolloutSpec_SetInternalExtension.json"
$SetInternalExtensionArmParametersFilename = "ArmParameters_SetInternalExtension.json"

$AllRegionsStageName = "StageAll"

$PublisherName = $ExtensionInfoXmlContent.ExtensionInfo.ExtensionImage.ProviderNameSpace
$ExtensionTypeName = $ExtensionInfoXmlContent.ExtensionInfo.ExtensionImage.Type
$ExtensionVersion = If ($UseBuildVersionForExtnVersion) {$BuildVersion} Else {$ExtensionInfoXmlContent.ExtensionInfo.ExtensionImage.Version}

# Remove any extra \ at the end.
$outputDir = $outputDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

# Create the EV2 artifacts folder structure
$ServiceGroupRoot = Create-DeploymentFolder -rootPath $outputDir -subdirectory 'ServiceGroupRoot'
$Param_path = Create-DeploymentFolder -rootPath $ServiceGroupRoot -subdirectory 'Parameters'
$Template_path = Create-DeploymentFolder -rootPath $ServiceGroupRoot -subdirectory 'Templates'

# Add build version file. This is the build version and Not Extension version
Create-BuildVersionFile -buildVersion $buildVersion

# Generate the set of EV2 artifacts for each cloud type
foreach ($CloudType in $ExtensionInfoXmlContent.ExtensionInfo.CloudTypes.ChildNodes)
{
    $CloudName =  $CloudType.Name

    # Create ServiceModel
    Create-ServiceModel -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent

    # Create Rollout specs
    Create-RolloutSpec-RegisterExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-RolloutSpecs-PublishExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-RolloutSpec-SetExternalExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    Create-RolloutSpec-SetInternalExtension -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent

    # Create ARM template files
    Create-ArmTemplateFiles -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent

    # Create Rollout and ARM parameters file
    Create-ParametersFiles -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
}

# Copy extension package file to the servicegrouproot folder if it does not exist
$PackageFileDestinationPath = Join-Path -Path $ServiceGroupRoot -ChildPath (Split-Path $PackageFile -leaf)
if(!(Test-Path -Path $PackageFileDestinationPath))
{
    Copy-Item -Path $PackageFile -Destination $PackageFileDestinationPath -Force
}
