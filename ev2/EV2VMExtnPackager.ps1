<#
.SYNOPSIS
    Generate the artifacts required for EV2 deployment for all environments for publishing VM Extensions
#>
param(
    [Parameter(Mandatory=$True, HelpMessage="Output directory where ServiceGroupRoot is created.")]
    [string]$outputDir,

    [parameter(mandatory=$True, HelpMessage="The extension info file with file path.")]
    [ValidateScript({Test-Path $_})]
    [string] $ExtensionInfoFile,

    [parameter(mandatory=$False, HelpMessage="The version of the build.")]
    [string] $BuildVersion,

    [parameter(mandatory=$False, HelpMessage="True, if placeholder ==buildversion== in zipFile name in ExtensionInfo file must be replaced with build version.")]
    [switch] $ReplaceBuildVersionInFileName,

    [parameter(mandatory=$False, HelpMessage="True, if build version must be used as the VM extension version as well.")]
    [switch] $UseBuildVersionForExtnVersion,

    [parameter(mandatory=$False, HelpMessage="True, if placeholder ==extensionversion== in zipFile name in ExtensionInfo file must be replaced with extension version.")]
    [switch] $ReplaceExtensionVersionInFileName
    )

    # Set global constants
    Set-Variable -Name "EDPEV2_AUTH_MGMTCERT" -Value "ManagementCert" -Option ReadOnly -Scope global -Force
    Set-Variable -Name "EDPEV2_AUTH_APPID_CERT" -Value "AppIdWithCert" -Option ReadOnly -Scope global -Force
    Set-Variable -Name "EDPEV2_AUTH_APPID_SECRET" -Value "AppIdWithSecret" -Option ReadOnly -Scope global -Force

<#
.SYNOPSIS
    Get the payload properties for Uploading the extension
#>
function Get-UploadPayloadProperties
{
    [CmdletBinding()]
    param(
        [string] $ExtensionOperationName,
        [string] $ExtnZipFileName,
        [string] $ExtnStorageContainer,
        [string] $ExtnStorageAccountKVConnection
        )

    $AParametersValues_hash = [ordered]@{}
    $AParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $AParametersValues_hash -ParameterName "ExtensionOperationName" -ParameterValue "UploadExtension"
    $AParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $AParametersValues_hash -ParameterName "ContainerName" -ParameterValue "$($ExtnStorageContainer)"

    $APathHashtable = @{}
    $APathHashtable.Add("path","$($ExtnZipFileName)")
    $AReferenceHashtable = @{}
    $AReferenceHashtable.Add("reference",$APathHashtable)

    $AParametersValues_hash.Add("SASUri",$AReferenceHashtable)

    $KVStorageAccountSecretHashtable = @{}
    $KVStorageAccountSecretHashtable.Add("secretId", $ExtnStorageAccountKVConnection);

    $RefHashtable = @{}
    $RefHashtable.Add("provider", "AzureKeyVault")
    $RefHashtable.Add("parameters", $($KVStorageAccountSecretHashtable))

    $TargetStorageAccountSecretHashtable = @{}
    $TargetStorageAccountSecretHashtable.Add("reference", $RefHashtable)

    $AParametersValues_hash.Add("TargetStorageAccountSecret", $TargetStorageAccountSecretHashtable)

    $AParametersValues_hash
}

<#
.SYNOPSIS
    Get the rollout parameters for Uploading the extension
#>
function Get-RolloutParameterFileForUpload
{
    [CmdletBinding()]
    param(
        [string] $KVCertificateSecretPath, 
        [string] $ExtnZipFileName,
        [string] $ExtnStorageContainer,
        [string] $ExtnStorageAccountKVConnection,
        [string] $ExtnShortName,
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [string] $AuthenticationType
        )

    $ExtnPublishingStageName = "Upload-VMExtension"
    $ExtensionOperationName = "UploadExtension"
    $FileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath "Parameters" | Join-Path -ChildPath "Params_$($CloudName)_$($ExtnShortName)_CopyVMExtension.json"

    # Generate Rollout Parameters
    [string] $Parameter_Template_File = Get-RolloutParameterFileTemplate
    $Parameters_json = ConvertFrom-Json -InputObject $Parameter_Template_File

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Get-ConnectionParametersForRolloutParams -ExtnPublishingStageName $ExtnPublishingStageName `
                                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                        -AuthenticationType $AuthenticationType

    $UploadPayloadHash = Get-UploadPayloadProperties -ExtensionOperationName $ExtensionOperationName `
                                                        -ExtnZipFileName $ExtnZipFileName `
                                                        -ExtnStorageContainer $ExtnStorageContainer `
                                                        -ExtnStorageAccountKVConnection $ExtnStorageAccountKVConnection

    $ParametersValues_hash.Add("PayloadProperties", $UploadPayloadHash)
    
    $Parameters_json.Extensions += $ParametersValues_hash

    $Parameters_json | ConvertTo-Json -Depth 30 | out-file $FileWithPath -Encoding utf8 -Force
}

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
    Get the template file for Parameters
    Returns the json file like below

    {
        "$schema":  "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
        "contentVersion":  "1.0.0.0",
        "paths":  [
                  ],
        "parameters":  {
                       }
    }

#>
function Get-ParameterFileTemplate
{
    [CmdletBinding()]
    param()

    $hashTemplateParameterFile = [ordered]@{}
    $emptyArray = @()
    $emptyHashtable = @{}

    $hashTemplateParameterFile.Add('$schema','http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#')
    $hashTemplateParameterFile.Add('contentVersion','1.0.0.0')
    $hashTemplateParameterFile.Add('paths',$emptyArray)
    $hashTemplateParameterFile.Add('parameters',$emptyHashtable)

    $hashTemplateParameterFile | ConvertTo-Json -Depth 10
}

<#
.SYNOPSIS
    Get the rollout parameters for Uploading the extension
#>
function Get-TemplateFile
{
    [CmdletBinding()]
    param(
        [string] $TemplateFilePath, 
        [string] $TemplateFileName
    )

    $TemplateFileWithPath = Join-Path -Path $TemplateFilePath -ChildPath $TemplateFileName

    $hashTemplateParameterFile = [ordered]@{}
    $emptyArray = @()
    $emptyHashtable = @{}

    $hashTemplateParameterFile.Add('$schema','http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#')
    $hashTemplateParameterFile.Add('contentVersion','1.0.0.0')
    $hashTemplateParameterFile.Add('parameters',$emptyHashtable)
    $hashTemplateParameterFile.Add('resources',$emptyArray)
    $hashTemplateParameterFile.Add('variables',$emptyHashtable)

    $hashTemplateParameterFile | ConvertTo-Json -Depth 10 | out-file $TemplateFileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Get the template for RolloutParameter file
    Returns the json file like below

    {
        "$schema":  "http://schema.express.azure.com/schemas/2015-01-01-alpha/RolloutParameters.json",
        "ContentVersion":  "1.0.0.0",
        "Extensions":  [
                  ],
        "parameters":  {
                       },
        "mdmHealthChecks": [ 
                  ]
    }

#>
function Get-RolloutParameterFileTemplate
{
    [CmdletBinding()]
    param(
        [bool] $MdmHealthChecksPresent
    )

    $hashTemplateParameterFile = [ordered]@{}
    $emptyArray = @()
    
    $hashTemplateParameterFile.Add('$schema','http://schema.express.azure.com/schemas/2015-01-01-alpha/RolloutParameters.json')
    $hashTemplateParameterFile.Add('ContentVersion','1.0.0.0')
    $hashTemplateParameterFile.Add('Extensions',$emptyArray)
    $hashTemplateParameterFile.Add('wait', @(
    @{
        "name" = "wait24Hours"
        "properties" = @{ "duration" = "PT24H" }
    }))
    
    if ($MdmHealthChecksPresent -eq $true)
    {
        $hashTemplateParameterFile.Add('mdmHealthChecks',$emptyArray)
    }
    
    $hashTemplateParameterFile | ConvertTo-Json -Depth 10
}

<#
.SYNOPSIS
    Adds the parameter and value to the parameters hashtable
#>
function Add-ParameterToHashtable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        $ParametersHashtable,
        
        [Parameter(Mandatory=$True)]
        $ParameterName,

        [Parameter(Mandatory=$True)]
        $ParameterValue
    )

    $parameterValueInFile = @{"value" = "$ParameterValue"}
    $ParametersHashtable.Add("$ParameterName", $parameterValueInFile)

    $ParametersHashtable
}

<#
.SYNOPSIS
    Get part of the Rollout parameters
#>
function Get-ConnectionParametersForRolloutParams
{
    [CmdletBinding()]
    param(
        [string] $ExtnPublishingStageName,
        [string] $KVCertificateSecretPath,
        [string] $AuthenticationType
        )

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash.Add("Name", "$($ExtnPublishingStageName)")
    $ParametersValues_hash.Add("Type", "Microsoft.SiteRecovery/PublishPlatformExtensions")
    $ParametersValues_hash.Add("Version", "2018-10-01")

    Switch ($AuthenticationType)
    {
        $global:EDPEV2_AUTH_MGMTCERT {
            $PublishingCertificateHashtable = @{}
            $PublishingCertificateHashtable.Add("SecretId","$($KVCertificateSecretPath)")

            $ReferenceHashtable = @{}
            $ReferenceHashtable.Add("Provider", "AzureKeyVault")
            $ReferenceHashtable.Add("Parameters", $PublishingCertificateHashtable)

            $AuthenticationHashtable = @{}
            $AuthenticationHashtable.Add("Type","CertificateAuthentication")
            $AuthenticationHashtable.Add("Reference", $ReferenceHashtable)            
            break
        }

        $global:EDPEV2_AUTH_APPID_SECRET {
            $AuthenticationHashtable = @{}
            $AuthenticationHashtable.Add("Type","SystemCertificateAuthentication")
            break
        }
            
        $global:EDPEV2_AUTH_APPID_CERT {
            $AuthenticationHashtable = @{}
            $AuthenticationHashtable.Add("Type","SystemCertificateAuthentication")
            break
        }
    }

    $ConnectionPropertiesHashtable = @{}
    $ConnectionPropertiesHashtable.Add("MaxExecutionTime", "PT24H")
    $ConnectionPropertiesHashtable.Add("Authentication", $AuthenticationHashtable)

    $ParametersValues_hash.Add("ConnectionProperties", $ConnectionPropertiesHashtable)

    $ParametersValues_hash
}

<#
.SYNOPSIS
    Get MDM health checks part of the Rollout parameters
#>
function Get-MdmHealthChecksForRolloutParams
{
    [CmdletBinding()]
    param(
        [System.Object[]] $MDMHealthChecks,
        [string] $StageName
    )

    $ParametersValuesHashList = @()
    $MDMHealthChecks |foreach {
        $ParametersValues_hash = [ordered]@{}
        $ParametersValues_hash.Add("name", "$($_.HealthCheckName)$($StageName)")
        $ParametersValues_hash.Add("monitoringAccountName", "$($_.monitoringAccountName)")
        $ParametersValues_hash.Add("waitBeforeMonitorTimeInMinutes", "$($_.waitBeforeMonitorTimeInMinutes)")
        $ParametersValues_hash.Add("monitorTimeInMinutes", "$($_.monitorTimeInMinutes)")
        $ParametersValues_hash.Add("mdmHealthCheckEndPoint", "$($_.mdmHealthCheckEndPoint)")
        $HealthResourcesList = @()
        $healthResources = ($_.HealthResources | select -ExpandProperty childnodes | where {$_.name -like 'HealthResource'})
        $healthResources | foreach {
            $HealthResource_hash = [ordered]@{}
            $HealthResource_hash.Add("name", "$($_.HealthResourceName)")
            $HealthResource_hash.Add("resourceType", "$($_.ResourceType)")
            $Dimensions = ($_.Dimensions | select -ExpandProperty childnodes | where {$_.name -like 'Dimension'})
            $Dimension_hash = [ordered]@{}
            if($_.InjectStageAsDimension -eq "true" )
            {
                $Dimension_hash.Add("Stage", $StageName)
            }

            $Dimensions | foreach {
                $Dimension_hash.Add("$($_.dimensionName)", "$($_.'#text')")
            }
            
            $HealthResource_hash.Add("dimensions", $Dimension_hash)
            $HealthResourcesList += $HealthResource_hash
        }
        $ParametersValues_hash.Add("healthResources", $HealthResourcesList)
        $ParametersValuesHashList += ($ParametersValues_hash)
    }
        
    return $ParametersValuesHashList
}

<#
.SYNOPSIS
    Get the extension version
#>
function Get-ExtensionVersion
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml,
        [bool] $UseBuildVersionForExtnVersion,
        [string] $BuildVersion
        )

    $ExtnVersion = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Version

    if($UseBuildVersionForExtnVersion)
    {
        $ExtnVersion = $BuildVersion
    }

    $ExtnVersion
}

<#
.SYNOPSIS
    Get the updated zipfile name
#>
function Get-ZipfileName
{
    [CmdletBinding()]
    param(
        [xml] $ExtnInfoXml,
        [bool] $ReplaceBuildVersionInFileName,
        [bool] $ReplaceExtensionVersionInFileName,
        [string] $BuildVersion,
        [string] $ExtnVersion
        )

    $ExtnZipFileName = $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionZipFileName

    if($ReplaceBuildVersionInFileName)
    {
        $ExtnZipFileName = $ExtnZipFileName -replace '==buildversion==', $BuildVersion
    }

    if($ReplaceExtensionVersionInFileName)
    {
        $ExtnZipFileName = $ExtnZipFileName -replace '==extensionversion==', $ExtnVersion
    }

    $ExtnZipFileName
}

<#
.SYNOPSIS
    Get the rollout parameter file
#>
function Get-RolloutParameterFile
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml,
        [string] $ExtensionInfoFileName
        )

    $PublishingSubscriptionId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SubscriptionId
    $ExtnStorageAccountKVConnection = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVClassicStorageConnection
    $ExtnStorageContainer = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ClassicContainerName
    $AuthenticationType = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AuthenticationType
    $ExtnNamespace = $ExtnInfoXml.ExtensionInfo.ExtensionImage.ProviderNamespace
    $ExtnType = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Type
    $ExtnSupportedOS = $ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS
    $ExtnLabel = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Label
    $ExtnIsInternal = $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionIsAlwaysInternal.ToLowerInvariant()
    $ExtnShortName = $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionShortName

    if(!$AuthenticationType)
    {
        $AuthenticationType = "ManagementCert"
    }
        
    # initialize to empty string
    $KVCertificateSecretPath = ""
    $KVPathForAppSecret = ""
    $KVPathForAppCert = ""
    $ApplicationId = ""
    $TenantId = ""

    Switch ($AuthenticationType)
    {
        $global:EDPEV2_AUTH_MGMTCERT {
            $KVCertificateSecretPath = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVPathForCertSecret
            break
        }

        $global:EDPEV2_AUTH_APPID_SECRET {
            $KVPathForAppSecret = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVPathForAppSecret
            $ApplicationId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ApplicationId
            $TenantId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).TenantId
            break
        }
            
        $global:EDPEV2_AUTH_APPID_CERT {
            $KVPathForAppCert = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVPathForAppCert
            $ApplicationId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ApplicationId
            $TenantId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).TenantId
            break
        }
    }

    # The extension version is already updated to use BuildNumber if specified
    $ExtnVersion = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Version

    # The ExtensionZipFileName is updated to replace any placeholders for buildversion and extension version
    $ExtnZipFileName = $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionZipFileName

    $ExtnStorageAccountEndpointSuffix = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).StorageAccountEndpointSuffix
    $ExtnStorageAccountName = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ClassicStorageAccountName
    $ExtnBlobUri = "https://$($ExtnStorageAccountName).$($ExtnStorageAccountEndpointSuffix)/$($ExtnStorageContainer)/$($ExtnZipFileName)"

    $SDPStageCount = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions | select -ExpandProperty childnodes | where {$_.name -like 'Stage*'}).Count


    Get-RolloutParameterFileForUpload -KVCertificateSecretPath $KVCertificateSecretPath `
                                        -ExtnZipFileName $ExtnZipFileName `
                                        -ExtnStorageContainer $ExtnStorageContainer `
                                        -ExtnStorageAccountKVConnection $ExtnStorageAccountKVConnection `
                                        -ExtnShortName $ExtnShortName `
                                        -ServiceGroupRoot $ServiceGroupRoot `
                                        -CloudName $CloudName `
                                        -AuthenticationType $AuthenticationType

    Get-RolloutParameterFileForGetExtns -KVCertificateSecretPath $KVCertificateSecretPath `
                                        -SubscriptionId $PublishingSubscriptionId `
                                        -ExtnShortName $ExtnShortName `
                                        -ServiceGroupRoot $ServiceGroupRoot `
                                        -CloudName $CloudName `
                                        -AuthenticationType $AuthenticationType `
                                        -KVPathForAppCert $KVPathForAppCert `
                                        -KVPathForAppSecret $KVPathForAppSecret `
                                        -AppId $ApplicationId `
                                        -TenantId $TenantId

    Get-RolloutParameterFileForRegister -KVCertificateSecretPath $KVCertificateSecretPath `
                                        -SubscriptionId $PublishingSubscriptionId `
                                        -ExtensionInfoFileName $ExtensionInfoFileName `
                                        -ExtnBlobUri $ExtnBlobUri `
                                        -ExtnShortName $ExtnShortName `
                                        -ServiceGroupRoot $ServiceGroupRoot `
                                        -CloudName $CloudName `
                                        -AuthenticationType $AuthenticationType `
                                        -KVPathForAppCert $KVPathForAppCert `
                                        -KVPathForAppSecret $KVPathForAppSecret `
                                        -AppId $ApplicationId `
                                        -TenantId $TenantId

    $EV2HealthChecks = $($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EV2HealthChecks)
    $EnableMDMHealthCheck = $($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EnableMDMHealthCheck) -ieq "true"
    for($i=1; $i -le $SDPStageCount; $i++)
    {
        $stageName = "Stage$($i)"

        $ExtnRegions = $($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions.$stageName)
        Get-RolloutParameterFileForPromote -KVCertificateSecretPath $KVCertificateSecretPath `
                                            -SubscriptionId $PublishingSubscriptionId `
                                            -ExtnNamespace $ExtnNamespace `
                                            -ExtnType $ExtnType `
                                            -ExtnVersion $ExtnVersion `
                                            -ExtnIsInternal $ExtnIsInternal `
                                            -ExtnRegions $ExtnRegions `
                                            -SDPStage $stageName `
                                            -ExtnShortName $ExtnShortName `
                                            -ServiceGroupRoot $ServiceGroupRoot `
                                            -CloudName $CloudName `
                                            -ExtensionInfoFileName $ExtensionInfoFileName `
                                            -AuthenticationType $AuthenticationType `
                                            -KVPathForAppCert $KVPathForAppCert `
                                            -KVPathForAppSecret $KVPathForAppSecret `
                                            -AppId $ApplicationId `
                                            -TenantId $TenantId `
                                            -EnableMDMHealthCheck $EnableMDMHealthCheck `
                                            -EV2HealthChecks $EV2HealthChecks
    }

    # Get parameters for promoting the extension in ALL regions (value = Public)
        Get-RolloutParameterFileForPromote -KVCertificateSecretPath $KVCertificateSecretPath `
                                            -SubscriptionId $PublishingSubscriptionId `
                                            -ExtnNamespace $ExtnNamespace `
                                            -ExtnType $ExtnType `
                                            -ExtnVersion $ExtnVersion `
                                            -ExtnIsInternal $ExtnIsInternal `
                                            -ExtnRegions "Public" `
                                            -SDPStage "All" `
                                            -ExtnShortName $ExtnShortName `
                                            -ServiceGroupRoot $ServiceGroupRoot `
                                            -CloudName $CloudName `
                                            -ExtensionInfoFileName $ExtensionInfoFileName `
                                            -AuthenticationType $AuthenticationType `
                                            -KVPathForAppCert $KVPathForAppCert `
                                            -KVPathForAppSecret $KVPathForAppSecret `
                                            -AppId $ApplicationId `
                                            -TenantId $TenantId

    
    # Get parameters for updating the extension as Internal
    Get-RolloutParameterFileForInternal -KVCertificateSecretPath $KVCertificateSecretPath `
                                            -SubscriptionId $PublishingSubscriptionId `
                                            -ExtnNamespace $ExtnNamespace `
                                            -ExtnType $ExtnType `
                                            -ExtnVersion $ExtnVersion `
                                            -ExtnShortName $ExtnShortName `
                                            -ServiceGroupRoot $ServiceGroupRoot `
                                            -CloudName $CloudName `
                                            -ExtensionInfoFileName $ExtensionInfoFileName `
                                            -AuthenticationType $AuthenticationType `
                                            -KVPathForAppCert $KVPathForAppCert `
                                            -KVPathForAppSecret $KVPathForAppSecret `
                                            -AppId $ApplicationId `
                                            -TenantId $TenantId

    # Get parameters for deleting the extension (Unregister)
    Get-RolloutParameterFileForDelete -KVCertificateSecretPath $KVCertificateSecretPath `
                                            -SubscriptionId $PublishingSubscriptionId `
                                            -ExtnNamespace $ExtnNamespace `
                                            -ExtnType $ExtnType `
                                            -ExtnVersion $ExtnVersion `
                                            -ExtnShortName $ExtnShortName `
                                            -ServiceGroupRoot $ServiceGroupRoot `
                                            -CloudName $CloudName `
                                            -ExtensionInfoFileName $ExtensionInfoFileName `
                                            -AuthenticationType $AuthenticationType `
                                            -KVPathForAppCert $KVPathForAppCert `
                                            -KVPathForAppSecret $KVPathForAppSecret `
                                            -AppId $ApplicationId `
                                            -TenantId $TenantId

}

<#
.SYNOPSIS
    Get the rollout parameters for updating the extension as Internal
#>
function Get-AuthDetailsForPayload
{
    [CmdletBinding()]
    param(
        [string] $KVPathForAuth 
    )

    $KVSecretPathHashtable = @{}
    $KVSecretPathHashtable.Add("secretId", $KVPathForAuth);

    $RefHashtable = @{}
    $RefHashtable.Add("provider", "AzureKeyVault")
    $RefHashtable.Add("parameters", $($KVSecretPathHashtable))

    $AuthHashtable = @{}
    $AuthHashtable.Add("reference", $RefHashtable)

    $AuthHashtable
}

<#
.SYNOPSIS
    Get the rollout parameters for updating the extension as Internal
#>
function Get-RolloutParameterFileForInternal
{
    [CmdletBinding()]
    param(
        [string] $KVCertificateSecretPath, 
        [string] $SubscriptionId,
        [string] $ExtnNamespace,
        [string] $ExtnType,
        [string] $ExtnVersion,
        [string] $ExtnShortName,
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [string] $ExtensionInfoFileName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ExtnPublishingStageName = "Internal-VMExtension"
    $ExtensionOperationName = "UpdateExtensionToInternal"
    $FileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath "Parameters" | Join-Path -ChildPath "Params_$($CloudName)_$($ExtnShortName)_Internal.json"

    # Generate Rollout Parameters
    [string] $Parameter_Template_File = Get-RolloutParameterFileTemplate
    $Parameters_json = ConvertFrom-Json -InputObject $Parameter_Template_File

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Get-ConnectionParametersForRolloutParams -ExtnPublishingStageName $ExtnPublishingStageName `
                                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                        -AuthenticationType $AuthenticationType

    $PayloadHashtable = Get-UpdateInternalAndDeleteProperties -ExtensionOperationName $ExtensionOperationName `
                                                                -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                -SubscriptionId $SubscriptionId `
                                                                -ExtnNamespace $ExtnNamespace `
                                                                -ExtnType $ExtnType `
                                                                -ExtnVersion $ExtnVersion `
                                                                -ExtensionInfoFileName $ExtensionInfoFileName `
                                                                -AuthenticationType $AuthenticationType `
                                                                -KVPathForAppCert $KVPathForAppCert `
                                                                -KVPathForAppSecret $KVPathForAppSecret `
                                                                -AppId $ApplicationId `
                                                                -TenantId $TenantId

    $ParametersValues_hash.Add("PayloadProperties", $PayloadHashtable)
    
    $Parameters_json.Extensions += $ParametersValues_hash

    $Parameters_json | ConvertTo-Json -Depth 30 | out-file $FileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Get some of the the properties for updating the extension as Internal
#>
function Get-UpdateInternalAndDeleteProperties
{
    [CmdletBinding()]
    param(
        [string] $ExtensionOperationName, 
        [string] $KVCertificateSecretPath,
        [string] $SubscriptionId,
        [string] $ExtnNamespace,
        [string] $ExtnType,
        [string] $ExtnVersion,
        [string] $ExtensionInfoFileName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionOperationName" -ParameterValue "$($ExtensionOperationName)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "SubscriptionId" -ParameterValue "$($SubscriptionId)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionProviderNameSpace" -ParameterValue "$($ExtnNamespace)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionName" -ParameterValue "$($ExtnType)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionVersion" -ParameterValue "$($ExtnVersion)"

    $PathHashtable = @{}
    $PathHashtable.Add("path","Parameters\$ExtensionInfoFileName")
    $ReferenceHashtable = @{}
    $ReferenceHashtable.Add("reference",$PathHashtable)

    $ParametersValues_hash.Add("ExtensionConfigurationFile",$ReferenceHashtable)

    Switch ($AuthenticationType)
    {
        $global:EDPEV2_AUTH_MGMTCERT {
            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVCertificateSecretPath
            $ParametersValues_hash.Add("ManagementCertificate", $AuthHashtable)
            break
        }

        $global:EDPEV2_AUTH_APPID_SECRET {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppSecret

            $ParametersValues_hash.Add("ApplicationSecret", $AuthHashtable)
            break
        }
            
        $global:EDPEV2_AUTH_APPID_CERT {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppCert
            
            $ParametersValues_hash.Add("ApplicationCertificate", $AuthHashtable)
            break
        }
    }

    $ParametersValues_hash
}

<#
.SYNOPSIS
    Get the rollout parameters for updating the extension to Internal and deleting the extension (Unregister)
    Both these have the same payload properties
#>
function Get-RolloutParameterFileForDelete
{
    [CmdletBinding()]
    param(
        [string] $KVCertificateSecretPath, 
        [string] $SubscriptionId,
        [string] $ExtnNamespace,
        [string] $ExtnType,
        [string] $ExtnVersion,
        [string] $ExtnShortName,
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [string] $ExtensionInfoFileName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ExtnPublishingStageName = "Delete-VMExtension"
    $ExtensionOperationName = "UnregisterExtension"
    $FileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath "Parameters" | Join-Path -ChildPath "Params_$($CloudName)_$($ExtnShortName)_Delete.json"

    # Generate Rollout Parameters
    [string] $Parameter_Template_File = Get-RolloutParameterFileTemplate
    $Parameters_json = ConvertFrom-Json -InputObject $Parameter_Template_File

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Get-ConnectionParametersForRolloutParams -ExtnPublishingStageName $ExtnPublishingStageName `
                                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                        -AuthenticationType $AuthenticationType

    $PayloadHashtable = Get-UpdateInternalAndDeleteProperties -ExtensionOperationName $ExtensionOperationName `
                                                                -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                -SubscriptionId $SubscriptionId `
                                                                -ExtnNamespace $ExtnNamespace `
                                                                -ExtnType $ExtnType `
                                                                -ExtnVersion $ExtnVersion `
                                                                -ExtensionInfoFileName $ExtensionInfoFileName `
                                                                -AuthenticationType $AuthenticationType `
                                                                -KVPathForAppCert $KVPathForAppCert `
                                                                -KVPathForAppSecret $KVPathForAppSecret `
                                                                -AppId $ApplicationId `
                                                                -TenantId $TenantId

    $ParametersValues_hash.Add("PayloadProperties", $PayloadHashtable)
    
    $Parameters_json.Extensions += $ParametersValues_hash

    $Parameters_json | ConvertTo-Json -Depth 30 | out-file $FileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Get the rollout parameters for Promoting the extension
#>
function Get-RolloutParameterFileForPromote
{
    [CmdletBinding()]
    param(
        [string] $KVCertificateSecretPath, 
        [string] $SubscriptionId,
        [string] $ExtnNamespace,
        [string] $ExtnType,
        [string] $ExtnVersion,
        [string] $ExtnIsInternal,
        [string] $ExtnRegions,
        [string] $SDPStage,
        [string] $ExtnShortName,
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [string] $ExtensionInfoFileName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId,
        [bool] $EnableMDMHealthCheck,
        [System.Xml.XmlElement] $EV2HealthChecks
        )

    $ExtnPublishingStageName = "Promote-$($SDPStage)"
    $ExtensionOperationName = "UpdateExtension"
    $FileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath "Parameters" | Join-Path -ChildPath "Params_$($CloudName)_$($ExtnShortName)_Promote_$($SDPStage).json"
    
    $MdmHealthChecksPresent = $false
    if ($EnableMDMHealthCheck -eq $true)
    {
        $MDMHealthChecks = @()
        $MDMHealthChecks += ($EV2HealthChecks.MDMHealthChecks | select -ExpandProperty childnodes| where {$_.name -like 'MDMHealthCheck' -and $_.Stages -like "*$SDPStage*"})
        $MdmHealthChecksPresent = ($MDMHealthChecks.Count -gt 0)
    }

    # Generate Rollout Parameters
    [string] $Parameter_Template_File = Get-RolloutParameterFileTemplate -MdmHealthChecksPresent $MdmHealthChecksPresent
     
    $Parameters_json = ConvertFrom-Json -InputObject $Parameter_Template_File

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Get-ConnectionParametersForRolloutParams -ExtnPublishingStageName $ExtnPublishingStageName `
                                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                        -AuthenticationType $AuthenticationType

    $PayloadHashtable = Get-PromoteExtnProperties -ExtensionOperationName $ExtensionOperationName `
                                                        -SubscriptionId $SubscriptionId `
                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                        -ExtnNamespace $ExtnNamespace `
                                                        -ExtnType $ExtnType `
                                                        -ExtnVersion $ExtnVersion `
                                                        -ExtnIsInternal $ExtnIsInternal `
                                                        -ExtnRegions $ExtnRegions `
                                                        -ExtensionInfoFileName $ExtensionInfoFileName `
                                                        -AuthenticationType $AuthenticationType `
                                                        -KVPathForAppCert $KVPathForAppCert `
                                                        -KVPathForAppSecret $KVPathForAppSecret `
                                                        -AppId $ApplicationId `
                                                        -TenantId $TenantId

    $ParametersValues_hash.Add("PayloadProperties", $PayloadHashtable)
    
    $Parameters_json.Extensions += $ParametersValues_hash
    if ($MdmHealthChecksPresent -eq $true)
    {
        $Parameters_json.mdmHealthChecks += Get-MdmHealthChecksForRolloutParams -MDMHealthChecks $MDMHealthChecks -StageName $SDPStage
    }
    
    $Parameters_json | ConvertTo-Json -Depth 30 | out-file $FileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Get some of the the properties value for promoting the extension
#>
function Get-PromoteExtnProperties
{
    [CmdletBinding()]
    param(
        [string] $ExtensionOperationName, 
        [string] $SubscriptionId,
        [string] $KVCertificateSecretPath,
        [string] $ExtnNamespace,
        [string] $ExtnType,
        [string] $ExtnVersion,
        [string] $ExtnIsInternal,
        [string] $ExtnRegions,
        [string] $ExtensionInfoFileName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionOperationName" -ParameterValue "$($ExtensionOperationName)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "SubscriptionId" -ParameterValue "$($SubscriptionId)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionProviderNameSpace" -ParameterValue "$($ExtnNamespace)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionName" -ParameterValue "$($ExtnType)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionVersion" -ParameterValue "$($ExtnVersion)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "IsInternal" -ParameterValue "$($ExtnIsInternal)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "Regions" -ParameterValue "$($ExtnRegions)"

    $PathHashtable = @{}
    $PathHashtable.Add("path","Parameters\$ExtensionInfoFileName")
    $ReferenceHashtable = @{}
    $ReferenceHashtable.Add("reference",$PathHashtable)

    $ParametersValues_hash.Add("ExtensionConfigurationFile",$ReferenceHashtable)
    
    Switch ($AuthenticationType)
    {
        $global:EDPEV2_AUTH_MGMTCERT {
            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVCertificateSecretPath
            $ParametersValues_hash.Add("ManagementCertificate", $AuthHashtable)
            break
        }

        $global:EDPEV2_AUTH_APPID_SECRET {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppSecret

            $ParametersValues_hash.Add("ApplicationSecret", $AuthHashtable)
            break
        }
            
        $global:EDPEV2_AUTH_APPID_CERT {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppCert
            
            $ParametersValues_hash.Add("ApplicationCertificate", $AuthHashtable)
            break
        }
    }

    $ParametersValues_hash
}

<#
.SYNOPSIS
    Get the rollout parameters for Registering the extension
#>
function Get-RolloutParameterFileForRegister
{
    [CmdletBinding()]
    param(
        [string] $KVCertificateSecretPath, 
        [string] $SubscriptionId,
        [string] $ExtensionInfoFileName,
        [string] $ExtnBlobUri,
        [string] $ExtnShortName,
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ExtnPublishingStageName = "Register-VMExtension"
    $ExtensionOperationName = "RegisterExtension"
    $FileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath "Parameters" | Join-Path -ChildPath "Params_$($CloudName)_$($ExtnShortName)_Register.json"

    # Generate Rollout Parameters
    [string] $Parameter_Template_File = Get-RolloutParameterFileTemplate
    $Parameters_json = ConvertFrom-Json -InputObject $Parameter_Template_File

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Get-ConnectionParametersForRolloutParams -ExtnPublishingStageName $ExtnPublishingStageName `
                                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                        -AuthenticationType $AuthenticationType

    $PayloadHashtable = Get-RegisterExtnProperties -ExtensionOperationName $ExtensionOperationName `
                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                        -ExtensionInfoFileName $ExtensionInfoFileName `
                                                        -ExtnBlobUri $ExtnBlobUri `
                                                        -AuthenticationType $AuthenticationType `
                                                        -KVPathForAppCert $KVPathForAppCert `
                                                        -KVPathForAppSecret $KVPathForAppSecret `
                                                        -AppId $ApplicationId `
                                                        -TenantId $TenantId

    $ParametersValues_hash.Add("PayloadProperties", $PayloadHashtable)
    
    $Parameters_json.Extensions += $ParametersValues_hash

    $Parameters_json | ConvertTo-Json -Depth 30 | out-file $FileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Get some of the the properties for Registering the extension
#>
function Get-RegisterExtnProperties
{
    [CmdletBinding()]
    param(
        [string] $ExtensionOperationName, 
        [string] $KVCertificateSecretPath,
        [string] $ExtensionInfoFileName,
        [string] $ExtnBlobUri,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionOperationName" -ParameterValue "$($ExtensionOperationName)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "BlobUri" -ParameterValue "$($ExtnBlobUri)"

    $PathHashtable = @{}
    $PathHashtable.Add("path","Parameters\$ExtensionInfoFileName")
    $ReferenceHashtable = @{}
    $ReferenceHashtable.Add("reference",$PathHashtable)

    $ParametersValues_hash.Add("ExtensionConfigurationFile",$ReferenceHashtable)

    Switch ($AuthenticationType)
    {
        $global:EDPEV2_AUTH_MGMTCERT {
            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVCertificateSecretPath
            $ParametersValues_hash.Add("ManagementCertificate", $AuthHashtable)
            break
        }

        $global:EDPEV2_AUTH_APPID_SECRET {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppSecret

            $ParametersValues_hash.Add("ApplicationSecret", $AuthHashtable)
            break
        }
            
        $global:EDPEV2_AUTH_APPID_CERT {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppCert
            
            $ParametersValues_hash.Add("ApplicationCertificate", $AuthHashtable)
            break
        }
    }

    $ParametersValues_hash
}

<#
.SYNOPSIS
    Get the rollout parameters for Listing the extensions
#>
function Get-RolloutParameterFileForGetExtns
{
    [CmdletBinding()]
    param(
        [string] $KVCertificateSecretPath, 
        [string] $SubscriptionId,
        [string] $ExtnShortName,
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ExtnPublishingStageName = "GetPublishedExtensions"
    $ExtensionOperationName = "GetAllPublishedExtensions"
    $FileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath "Parameters" | Join-Path -ChildPath "Params_$($CloudName)_$($ExtnShortName)_GetExtensions.json"

    # Generate Rollout Parameters
    [string] $Parameter_Template_File = Get-RolloutParameterFileTemplate
    $Parameters_json = ConvertFrom-Json -InputObject $Parameter_Template_File

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Get-ConnectionParametersForRolloutParams -ExtnPublishingStageName $ExtnPublishingStageName `
                                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                                        -AuthenticationType $AuthenticationType

    $PayloadHashtable = Get-GetExtnProperties -ExtensionOperationName $ExtensionOperationName `
                                                        -SubscriptionId $SubscriptionId `
                                                        -KVCertificateSecretPath $KVCertificateSecretPath `
                                                        -AuthenticationType $AuthenticationType `
                                                        -KVPathForAppCert $KVPathForAppCert `
                                                        -KVPathForAppSecret $KVPathForAppSecret `
                                                        -AppId $ApplicationId `
                                                        -TenantId $TenantId

    $ParametersValues_hash.Add("PayloadProperties", $PayloadHashtable)
    
    $Parameters_json.Extensions += $ParametersValues_hash

    $Parameters_json | ConvertTo-Json -Depth 30 | out-file $FileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Get some of the properties for Listing the extension
#>
function Get-GetExtnProperties
{
    [CmdletBinding()]
    param(
        [string] $ExtensionOperationName, 
        [string] $SubscriptionId,
        [string] $KVCertificateSecretPath,
        [string] $AuthenticationType,
        [string] $KVPathForAppCert,
        [string] $KVPathForAppSecret,
        [string] $AppId,
        [string] $TenantId
        )

    $ParametersValues_hash = [ordered]@{}
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ExtensionOperationName" -ParameterValue "$($ExtensionOperationName)"
    $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "SubscriptionId" -ParameterValue "$($SubscriptionId)"

    Switch ($AuthenticationType)
    {
        $global:EDPEV2_AUTH_MGMTCERT {
            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVCertificateSecretPath
            $ParametersValues_hash.Add("ManagementCertificate", $AuthHashtable)
            break
        }

        $global:EDPEV2_AUTH_APPID_SECRET {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppSecret

            $ParametersValues_hash.Add("ApplicationSecret", $AuthHashtable)
            break
        }
            
        $global:EDPEV2_AUTH_APPID_CERT {
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "TenantId" -ParameterValue "$($TenantId)"
            $ParametersValues_hash = Add-ParameterToHashtable -ParametersHashtable $ParametersValues_hash -ParameterName "ApplicationId" -ParameterValue "$($AppId)"

            $AuthHashtable = Get-AuthDetailsForPayload -KVPathForAuth $KVPathForAppCert
            
            $ParametersValues_hash.Add("ApplicationCertificate", $AuthHashtable)
            break
        }
    }

    $ParametersValues_hash
}

<#
.SYNOPSIS
    Get the ServiceModel File
#>
function Get-ServiceModelFile
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml
        )

<# 
    *** Place holder for any cloud specific values ***

    switch($CloudName)
    {
        "Public" 
            {
                # $Ev2Environment = "Public"
                # $AzureFunctionLocation = "Southeast Asia"
                break
            }
        "Blackforest"
            {
                # $Ev2Environment = "Blackforest"
                # $AzureFunctionLocation = "Germany Central"
            }
        "Mooncake"
            {
                # $Ev2Environment = "Mooncake"
                # $AzureFunctionLocation = "China East"
            }
        "Fairfax"
            {
                # $Ev2Environment = "Fairfax"
                # $AzureFunctionLocation = "USDoD Central"
            }
        default
            {
                $Ev2Environment = "TBD"
                $AzureFunctionSubscriptionId = "TBD"
                $AzureFunctionLocation = "TBD"
                $AzureFunctionResourceGroup = "TBD"
                break
            }
    }
#>

    # The EV2 Environment is same as the CloudName!
    $Ev2Environment = $CloudName

    $ExtnShortName = $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionShortName
    $AzureFunctionSubscriptionId = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SubscriptionId
    $AzureFunctionResourceGroup = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureResourceGroupName
    $AzureFunctionLocation = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureLocation
    $ServiceModelTemplate = Get-ServiceModelTemplateFile -Ev2Environment $Ev2Environment

    $ServiceResourceGroups = @()

    $ServiceResourceGroupHash = @{}
    $ServiceResourceGroupHash.Add("AzureResourceGroupName","$AzureFunctionResourceGroup")
    $ServiceResourceGroupHash.Add("Location","$AzureFunctionLocation")
    $ServiceResourceGroupHash.Add("InstanceOf","ExtensionPublishResource_Instance")
    $ServiceResourceGroupHash.Add("AzureSubscriptionId","$AzureFunctionSubscriptionId")

    $ServiceResources = @()

    # =======================
    # Copy extension to storage account

    $ServiceResourceHashtable = @{}
    $ServiceResourceHashtable.Add("Name","Copy-VMExtension2Container")
    $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
    $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
    $ServiceResourceHashtable.Add("RolloutParametersPath","Parameters\Params_$($CloudName)_$($ExtnShortName)_CopyVMExtension.json")

    $ServiceResources += $ServiceResourceHashtable

    # =======================
    # Register

    $ServiceResourceHashtable = @{}
    $ServiceResourceHashtable.Add("Name","ExtensionPublishResource")
    $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
    $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
    $ServiceResourceHashtable.Add("RolloutParametersPath","Parameters\Params_$($CloudName)_$($ExtnShortName)_Register.json")

    $ServiceResources += $ServiceResourceHashtable

    # =======================
    # Get Published Extensions

    $ServiceResourceHashtable = @{}
    $ServiceResourceHashtable.Add("Name","GetPublishedExtensions")
    $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
    $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
    $ServiceResourceHashtable.Add("RolloutParametersPath","Parameters\Params_$($CloudName)_$($ExtnShortName)_GetExtensions.json")

    $ServiceResources += $ServiceResourceHashtable

    # =======================
    # Promote to regions

    $SDPStageCount = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions | select -ExpandProperty childnodes | where {$_.name -like 'Stage*'}).Count

    for($i=1; $i -le $SDPStageCount; $i++)
    {
        $stageName = "PromoteStage$($i)"
        $FileName = "Promote_Stage$($i)"
        $rolloutParameterFile = "Parameters\Params_$($CloudName)_$($ExtnShortName)_$($FileName).json"

        $ServiceResourceHashtable = @{}
        $ServiceResourceHashtable.Add("Name","$stageName")
        $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
        $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
        $ServiceResourceHashtable.Add("RolloutParametersPath","$rolloutParameterFile")

        $ServiceResources += $ServiceResourceHashtable
    }

    # =======================
    # Promote to ALL regions

    $ServiceResourceHashtable = @{}
    $ServiceResourceHashtable.Add("Name","PromoteAll")
    $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
    $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
    $ServiceResourceHashtable.Add("RolloutParametersPath","Parameters\Params_$($CloudName)_$($ExtnShortName)_Promote_All.json")

    $ServiceResources += $ServiceResourceHashtable

    # =======================
    # Update to Internal

    $ServiceResourceHashtable = @{}
    $ServiceResourceHashtable.Add("Name","UpdateInternal")
    $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
    $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
    $ServiceResourceHashtable.Add("RolloutParametersPath","Parameters\Params_$($CloudName)_$($ExtnShortName)_Internal.json")

    $ServiceResources += $ServiceResourceHashtable

    # =======================
    # Delete extension (Unregister)

    $ServiceResourceHashtable = @{}
    $ServiceResourceHashtable.Add("Name","DeleteExtension")
    $ServiceResourceHashtable.Add("InstanceOf","ExtensionPublishResource_ServiceResource")
    $ServiceResourceHashtable.Add("ArmParametersPath","Parameters\ArmParameters.json")
    $ServiceResourceHashtable.Add("RolloutParametersPath","Parameters\Params_$($CloudName)_$($ExtnShortName)_Delete.json")

    $ServiceResources += $ServiceResourceHashtable

    # =======================

    $ServiceResourceGroupHash.Add("ServiceResources",$ServiceResources)

    $ServiceResourceGroups += $ServiceResourceGroupHash

    $ServiceModelTemplate.Add("ServiceResourceGroups", $ServiceResourceGroups)

    $ServiceModelFile = Join-Path -Path $ServiceGroupRoot -ChildPath "$($CloudName)_$($ExtnShortName)_ServiceModel.json"

    $ServiceModelTemplate | ConvertTo-Json -Depth 30 | Out-File $ServiceModelFile -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Helper to get the servicemodel file
#>
function Get-ServiceModelTemplateFile
{
    [CmdletBinding()]
    param(
        [string] $Ev2Environment
        )

    $hashTemplateServiceModelFile = [ordered]@{}
    $emptyArray = @()
    $emptyHashtable = @{}

    $ServiceMetadataHashtable = @{}
    $ServiceMetadataHashtable.Add("ServiceGroup","VMExtension")
    $ServiceMetadataHashtable.Add("Environment","$($Ev2Environment)")

    $hashTemplateServiceModelFile.Add('$schema','http://schema.express.azure.com/schemas/2015-01-01-alpha/ServiceModel.json')
    $hashTemplateServiceModelFile.Add('ContentVersion','1.0.0.0')
    $hashTemplateServiceModelFile.Add('ServiceMetadata',$ServiceMetadataHashtable)

    $ServiceResourceDefinitionsArray = @()

    $ServiceResourceDefinitionsHashtable = @{}
    $ServiceResourceDefinitionsHashtable.Add("Name","ExtensionPublishResource_ServiceResource")
    $ServiceResourceDefinitionsHashtable.Add("ArmTemplatePath","Templates\UpdateConfig.Template.json")

    $ServiceResourceDefinitionsArray += $ServiceResourceDefinitionsHashtable

    $ServiceResourceGroupDefinitionsHashtable = @{}
    $ServiceResourceGroupDefinitionsHashtable.Add("Name","ExtensionPublishResource_Instance")
    $ServiceResourceGroupDefinitionsHashtable.Add("ServiceResourceDefinitions", $ServiceResourceDefinitionsArray)

    $ServiceResourceGroupDefinitionsArray = @()
    $ServiceResourceGroupDefinitionsArray += $ServiceResourceGroupDefinitionsHashtable
    $hashTemplateServiceModelFile.Add('ServiceResourceGroupDefinitions',$ServiceResourceGroupDefinitionsArray)

    $hashTemplateServiceModelFile 
}

<#
.SYNOPSIS
    Get all the the rollout specs for the given Cloud
#>
function Get-AllRolloutSpecFiles
{
    [CmdletBinding()]
    param(
        [string] $ServiceGroupRoot,
        [string] $CloudName,
        [xml] $ExtnInfoXml,
        [string] $RolloutTypes
        )

    $RolloutSpecs = @()

    # Extension version is already repalced with BuildNumber, if specified
    $ExtnVersion = $ExtnInfoXml.ExtensionInfo.ExtensionImage.Version

    $ExtnShortName = $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionShortName
    $ServiceModelPath = "$($CloudName)_$($ExtnShortName)_ServiceModel.json"
    
    # ===============================
    # List all extensions
    $StepName = "Get-PublishedExtensions"
    $TargetName = "GetPublishedExtensions"
    $ActionName = "GetPublishedExtensions"
    $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_ListAll.json"
    $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
    
    Get-RolloutSpecFile -StepName $StepName `
                        -TargetName $TargetName `
                        -ActionName $ActionName `
                        -ServiceModelPath $ServiceModelPath `
                        -ExtnShortName $ExtnShortName `
                        -ExtnVersion $ExtnVersion `
                        -RolloutSpecFileWithPath $RolloutSpecFileWithPath

    # ===============================
    # Upload extension
    $StepName = "Upload-VMExtension"
    $TargetName = "Copy-VMExtension2Container"
    $ActionName = "Upload-VMExtension"
    $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_Upload.json"
    $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
    $RolloutSpecs += $RolloutSpecFileWithPath
    
    Get-RolloutSpecFile -StepName $StepName `
                        -TargetName $TargetName `
                        -ActionName $ActionName `
                        -ServiceModelPath $ServiceModelPath `
                        -ExtnShortName $ExtnShortName `
                        -ExtnVersion $ExtnVersion `
                        -RolloutSpecFileWithPath $RolloutSpecFileWithPath

    # ===============================
    # Register extension
    $StepName = "Register-VMExtension"
    $TargetName = "ExtensionPublishResource"
    $ActionName = "Register-VMExtension"
    $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_Register.json"
    $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
    $RolloutSpecs += $RolloutSpecFileWithPath
    
    Get-RolloutSpecFile -StepName $StepName `
                        -TargetName $TargetName `
                        -ActionName $ActionName `
                        -ServiceModelPath $ServiceModelPath `
                        -ExtnShortName $ExtnShortName `
                        -ExtnVersion $ExtnVersion `
                        -RolloutSpecFileWithPath $RolloutSpecFileWithPath

    # ===============================
    # Promote SDP stages

    $RolloutTypeList = $RolloutTypes.Split(";",[System.StringSplitOptions]::RemoveEmptyEntries)
    if($RolloutTypeList.Count -eq 0)
    {
       $RolloutTypeList = @('Hotfix')
    }
    
    $SDPStageCount = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions | select -ExpandProperty childnodes | where {$_.name -like 'Stage*'}).Count

    for($i=1; $i -le $SDPStageCount; $i++)
    {
        $stageName = "Stage$($i)"

        $StepName = "Promote-$stageName"
        $TargetName = "Promote$stageName"
        $ActionName = "Promote-$stageName"
        for($j=0; $j -lt $RolloutTypeList.Count; $j++)
        {
            $RolloutTypeSufffix = ''
            $RolloutType=$RolloutTypeList[$j]
            $MDMHealthCheckActionsToAdd = ''
            if($RolloutType -ne 'Hotfix')
            {
                $RolloutTypeSufffix = $RolloutType + "_"
            }
            
            $EnableMDMHealthCheck = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EnableMDMHealthCheck)
            if($EnableMDMHealthCheck -eq $true)
            {
                $MDMhealthChecks = @()
                $MDMhealthChecks += ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EV2HealthChecks.MDMHealthChecks | select -ExpandProperty childnodes| where {$_.name -like 'MDMHealthCheck' -and $_.Stages -like "*$stageName*" -and $_.RolloutTypes -like "*$RolloutType*"})
                $MDMHealthChecks |foreach {
                    $MDMHealthCheckActionsToAdd += ",mdmHealthCheck/" + $_.HealthCheckName + $stageName
                }
            }
            
            $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_$($RolloutTypeSufffix)Promote$stageName.json"
            $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
            $RolloutSpecs += $RolloutSpecFileWithPath

            Get-RolloutSpecFile -StepName $StepName `
                            -TargetName $TargetName `
                            -ActionName $ActionName `
                            -ServiceModelPath $ServiceModelPath `
                            -ExtnShortName $ExtnShortName `
                            -ExtnVersion $ExtnVersion `
                            -RolloutSpecFileWithPath $RolloutSpecFileWithPath `
                            -RolloutType $RolloutType `
                            -MDMHealthCheckActionsToAdd $MDMHealthCheckActionsToAdd
        }                    
    }

    # ===============================
    # Promote All
    $StepName = "Promote-All"
    $TargetName = "PromoteAll"
    $ActionName = "Promote-All"
    $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_PromoteAll.json"
    $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
    $RolloutSpecs += $RolloutSpecFileWithPath
    
    Get-RolloutSpecFile -StepName $StepName `
                        -TargetName $TargetName `
                        -ActionName $ActionName `
                        -ServiceModelPath $ServiceModelPath `
                        -ExtnShortName $ExtnShortName `
                        -ExtnVersion $ExtnVersion `
                        -RolloutSpecFileWithPath $RolloutSpecFileWithPath

    # ===============================
    # Update extension Internal
    $StepName = "Internal-VMExtension"
    $TargetName = "UpdateInternal"
    $ActionName = "Internal-VMExtension"
    $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_Internal.json"
    $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
    
    Get-RolloutSpecFile -StepName $StepName `
                        -TargetName $TargetName `
                        -ActionName $ActionName `
                        -ServiceModelPath $ServiceModelPath `
                        -ExtnShortName $ExtnShortName `
                        -ExtnVersion $ExtnVersion `
                        -RolloutSpecFileWithPath $RolloutSpecFileWithPath

    # ===============================
    # Delete extension
    $StepName = "Delete-VMExtension"
    $TargetName = "DeleteExtension"
    $ActionName = "Delete-VMExtension"
    $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName)_Delete.json"
    $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
    
    Get-RolloutSpecFile -StepName $StepName `
                        -TargetName $TargetName `
                        -ActionName $ActionName `
                        -ServiceModelPath $ServiceModelPath `
                        -ExtnShortName $ExtnShortName `
                        -ExtnVersion $ExtnVersion `
                        -RolloutSpecFileWithPath $RolloutSpecFileWithPath

   # Consolidating all rolloutspecs into a single RolloutSpec file
   $RolloutSpecFileName = "RolloutSpec_$($CloudName)_$($ExtnShortName).json"
   $RolloutSpecFileWithPath = Join-Path -Path $ServiceGroupRoot -ChildPath $RolloutSpecFileName
   $CummulativeRolloutSpec = Get-Content $RolloutSpecs[0] | ConvertFrom-Json
   for($i = 1; $i -lt $RolloutSpecs.Count; $i++)
   {
       $RolloutSpec = Get-Content $RolloutSpecs[$i] | ConvertFrom-Json
       $NewOrchestratedStep = $RolloutSpec.OrchestratedSteps[0]
       
       # finding the last orchestrated step
       $LastOrchestratedStep = $CummulativeRolloutSpec.OrchestratedSteps[$CummulativeRolloutSpec.OrchestratedSteps.Count - 1]

       if(-not $NewOrchestratedStep.dependsOn)
       {
           $NewOrchestratedStep | Add-Member -NotePropertyName 'dependsOn' -NotePropertyValue @() 
       }
       
       $NewOrchestratedStep.dependsOn +=$LastOrchestratedStep.Name

       $MdmHealthModelAddedInLastStep = ($LastOrchestratedStep.Actions | %{ $_ -like "mdmHealthCheck/*"}) -contains $true

       if($NewOrchestratedStep.Name.StartsWith("Promote", [System.StringComparison]::InvariantCultureIgnoreCase) -and 
          $LastOrchestratedStep.Name.StartsWith("Promote", [System.StringComparison]::InvariantCultureIgnoreCase) -and
          (-not $MdmHealthModelAddedInLastStep))
       {
           # Adding 24 hour wait if both the last and the new orchestrated steps are "Promote" steps and there is no MDM health checks present in previous stage.
           $NewOrchestratedStep.Actions = @("wait/wait24Hours") + $NewOrchestratedStep.Actions
       }

       $CummulativeRolloutSpec.OrchestratedSteps += $NewOrchestratedStep
   }

   $CummulativeRolloutSpec | ConvertTo-Json -Depth 30 | Out-File $RolloutSpecFileWithPath -Encoding utf8 -Force
}

<#
.SYNOPSIS
    Helper to get the rollout spec file
#>
function Get-RolloutSpecFile
{
    [CmdletBinding()]
    param(
        [string] $StepName,
        [string] $TargetName,
        [string] $ActionName,
        [string] $ServiceModelPath,
        [string] $ExtnShortName,
        [string] $ExtnVersion,
        [string] $RolloutSpecFileWithPath,
        [string] $RolloutType,
        [string] $MDMHealthCheckActionsToAdd
        )

    $hashTemplateRolloutSpec = [ordered]@{}

    $emptyArray = @()
    $emptyHashtable = @{}
    $ServiceMetadataHashtable = @{}

    $hashTemplateRolloutSpec.Add('$schema',"http://schema.express.azure.com/schemas/2015-01-01-alpha/RolloutSpec.json")
    $hashTemplateRolloutSpec.Add("ContentVersion","1.0.0.0")
    
    if($RolloutType -eq '')
    {
        $RolloutType="Hotfix"
    }
    
    $rolloutMetadataHashtable = @{}
    $rolloutMetadataHashtable.Add("ServiceModelPath", $ServiceModelPath)
    $rolloutMetadataHashtable.Add("Name", "$ExtnShortName $ExtnVersion")
    $rolloutMetadataHashtable.Add("RolloutType", $RolloutType)

    $ParametersHash = @{}
    $ParametersHash.Add("ServiceGroupRoot","ServiceGroupRoot")
    $ParametersHash.Add("VersionFile","buildver.txt")

    $BuildSourceHashtable = @{}
    $BuildSourceHashtable.Add("BuildSourceType","SmbShare")
    $BuildSourceHashtable.Add("Parameters", $ParametersHash)

    $rolloutMetadataHashtable.Add("BuildSource", $BuildSourceHashtable)

    $hashTemplateRolloutSpec.Add("RolloutMetadata", $rolloutMetadataHashtable)

    $OrchestratedSteps = @()
    $OrchestratedStepHashTable = @{}

    $OrchestratedStepHashTable.Add("Name","$StepName")
    $OrchestratedStepHashTable.Add("TargetType","ServiceResource")
    $OrchestratedStepHashTable.Add("TargetName","$TargetName")
    $ActionsArray = @("Extension/$($ActionName)")
    $ActionsArray += ($MDMHealthCheckActionsToAdd.Split(",",[System.StringSplitOptions]::RemoveEmptyEntries))
    $OrchestratedStepHashTable.Add("Actions",$ActionsArray)

    $OrchestratedSteps += $OrchestratedStepHashTable

    $hashTemplateRolloutSpec.Add("OrchestratedSteps", $OrchestratedSteps)

    $hashTemplateRolloutSpec | ConvertTo-Json -Depth 30 | Out-File $RolloutSpecFileWithPath -Encoding utf8 -Force
}


<#
.SYNOPSIS
    Check if the input object is null or empty. If yes, Throw exception and exit
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
        throw $ErrorMessage
        exit
    }
}

<#
.SYNOPSIS
    Throw the give exception and exit
#>
function ThrowAndExit
{
    [CmdletBinding()]
    param(
        [string] $ErrorMessage
        )

    throw $ErrorMessage
    exit
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

    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionShortName.Trim() -ErrorMessage "Extension ShortName is null."
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionZipFileName.Trim() -ErrorMessage "Extension ZipFile is null."
    IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionIsAlwaysInternal.Trim() -ErrorMessage "ExtensionIsAlwaysInternal is null."
    if($ExtnInfoXml.ExtensionInfo.PipelineConfig.RolloutTypes -ne $null)
    {
        $PipelineConfigRolloutTypes = $ExtnInfoXml.ExtensionInfo.PipelineConfig.RolloutTypes.Split(";",[System.StringSplitOptions]::RemoveEmptyEntries)
    }
    
    # ExtensionIsAlwaysInternal must be True or False only
    if(!($ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionIsAlwaysInternal -ieq "True" -or $ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionIsAlwaysInternal -ieq "False"))
    {
        ThrowAndExit -ErrorMessage "ExtensionIsAlwaysInternal must be true or false only."
    }

    # SupportedOS must be Windows or Linux only
    if(!($ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS -ieq "Windows" -or $ExtnInfoXml.ExtensionInfo.ExtensionImage.SupportedOS -ieq "Linux"))
    {
        ThrowAndExit -ErrorMessage "SupportedOS must be Windows or Linux only."
    }
    
    # ExtensionShortName should not contain spaces
    if ($ExtnInfoXml.ExtensionInfo.PipelineConfig.ExtensionShortName -contains " ")
    {
        ThrowAndExit -ErrorMessage "ShortName must not contain spaces."
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

        if(!($CloudName -ieq "Public" -or $CloudName -ieq "Blackforest" -or $CloudName -ieq "Mooncake" -or $CloudName -ieq "Fairfax" -or $CloudName -ieq "USSec" -or $CloudName -ieq "USNat"))
        {
            ThrowAndExit -ErrorMessage "CloudTypes supported at this time are Public, Blackforest, Mooncake, Fairfax, USSec and USNat Not '$($CloudName)'."
        }

        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SubscriptionId -ErrorMessage "SubscriptionId for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureResourceGroupName -ErrorMessage "AzureResourceGroupName for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AzureLocation -ErrorMessage "AzureLocation for Cloud $($CloudName) is not valid."
        
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ClassicStorageAccountName -ErrorMessage "ClassicStorageAccountName for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ClassicContainerName -ErrorMessage "ClassicContainerName for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).StorageAccountEndpointSuffix -ErrorMessage "StorageAccountEndpointSuffix for Cloud $($CloudName) is not valid."
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVClassicStorageConnection -ErrorMessage "KVClassicStorageConnection for Cloud $($CloudName) is not valid."
        
        $AuthenticationType = $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).AuthenticationType
        if(!$AuthenticationType)
        {
            $AuthenticationType = "ManagementCert"
        }

        if($AuthenticationType -ine "ManagementCert" -and $AuthenticationType -ine "AppIdWithCert")
        {
            ThrowAndExit -ErrorMessage "AuthenticationType must be ManagementCert or AppIdWithCert only in Cloud '$($CloudName)'."
        }

        Switch ($AuthenticationType)
        {
            $global:EDPEV2_AUTH_MGMTCERT {
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVPathForCertSecret -ErrorMessage "KVPathForCertSecret for Cloud $($CloudName) is not valid.";
                break
            }

            $global:EDPEV2_AUTH_APPID_SECRET {
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).TenantId -ErrorMessage "TenantId for Cloud $($CloudName) is not valid.";
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ApplicationId -ErrorMessage "ApplicationId for Cloud $($CloudName) is not valid.";
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVPathForAppSecret -ErrorMessage "KVPathForAppSecret for Cloud $($CloudName) is not valid.";
                break
            }
            
            $global:EDPEV2_AUTH_APPID_CERT {
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).TenantId -ErrorMessage "TenantId for Cloud $($CloudName) is not valid.";
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).ApplicationId -ErrorMessage "ApplicationId for Cloud $($CloudName) is not valid.";
                IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).KVPathForAppCert -ErrorMessage "KVPathForAppCert for Cloud $($CloudName) is not valid.";
                break
            }
        }

        $EnableMDMHealthCheck = $($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EnableMDMHealthCheck)
        $MDMHealthChecks = @()
        $MDMHealthChecks += ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EV2HealthChecks.MDMHealthChecks | select -ExpandProperty childnodes| where {$_.name -like 'MDMHealthCheck' -and $_.Stages -like "*Stage*"})
        if($EnableMDMHealthCheck -eq $true -and $MDMHealthChecks.Count -eq 0)
        {
            ThrowAndExit -ErrorMessage "If EnableMDMHealthCheck is enabled, then the extension info must include MDMHealthChecks child node inside EV2HealthChecks node for at least one stage in Cloud '$($CloudName)'."
        }
            
        IfNullThrowAndExit -inputObject $ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions -ErrorMessage "SDPRegions for Cloud $($CloudName) is not valid."

        $SDPStageCount = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).SDPRegions | select -ExpandProperty childnodes | where {$_.name -like 'Stage*'}).Count
        
        if($SDPStageCount -lt 2)
        {
            # Some publishers only publish to 2 canary regions. Also, Blackforest has only 2 regions.
            ThrowAndExit -ErrorMessage "SDP is not being followed for $($CloudName)."
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
            
            $MDMHealthChecks = ($ExtnInfoXml.ExtensionInfo.CloudTypes.$($CloudName).EV2HealthChecks.MDMHealthChecks | select -ExpandProperty childnodes| where {$_.name -like 'MDMHealthCheck' -and $_.Stages -like "*$stageName*"})
            
            if($EnableMDMHealthCheck -eq $true -and $MDMHealthChecks.Count -gt 0)
            {
                $MDMHealthChecks | foreach {
                    IfNullThrowAndExit -inputObject $_.HealthCheckName -ErrorMessage "Each MDMHealthCheck must include HealthCheckName for Stage $($stageName) in Cloud '$($CloudName)'."
                    IfNullThrowAndExit -inputObject $_.monitoringAccountName -ErrorMessage "Each MDMHealthCheck must include monitoringAccountName for Stage $($stageName) in Cloud '$($CloudName)'."
                    IfNullThrowAndExit -inputObject $_.waitBeforeMonitorTimeInMinutes -ErrorMessage "Each MDMHealthCheck must include waitBeforeMonitorTimeInMinutes for Stage $($stageName) in Cloud '$($CloudName)'."
                    IfNullThrowAndExit -inputObject $_.monitorTimeInMinutes -ErrorMessage "Each MDMHealthCheck must include monitorTimeInMinutes for Stage $($stageName) in Cloud '$($CloudName)'."
                    IfNullThrowAndExit -inputObject $_.mdmHealthCheckEndPoint -ErrorMessage "Each MDMHealthCheck must include mdmHealthCheckEndPoint for Stage $($stageName) in Cloud '$($CloudName)'."
                    $RolloutTypeList = $_.RolloutTypes.Split(";",[System.StringSplitOptions]::RemoveEmptyEntries)
                    $RolloutTypeList | foreach {
                        if (-not $PipelineConfigRolloutTypes.Contains($_))
                        {
                            ThrowAndExit -ErrorMessage "RolloutType $_ is not among the RolloutTypes mentioned in PipelineConfig i.e. $PipelineConfigRolloutTypes in Cloud '$($CloudName)'."
                        }
                    }
                    
                    $healthResources = ($_.HealthResources | select -ExpandProperty childnodes | where {$_.name -like 'HealthResource'})
                    $healthResources | foreach {
                        IfNullThrowAndExit -inputObject $_.HealthResourceName -ErrorMessage "Each HealthResource must include HealthCheckName for Stage $($stageName) in Cloud '$($CloudName)'."
                        IfNullThrowAndExit -inputObject $_.ResourceType -ErrorMessage "Each MDMHealthCheck must include ResourceType for Stage $($stageName) in Cloud '$($CloudName)'."
                    }
                    
                }                
            }
        }
    }
}

# =================================================================================================
# Main execution 
# =================================================================================================
# remove any extra \ at the end. This will cause errors in file paths
$outputDir = $outputDir.TrimEnd('\')

# Create the EV2 folder structure
$ServiceGroupRoot = Create-DeploymentFolder -rootPath $outputDir -subdirectory 'ServiceGroupRoot'
$Param_path = Create-DeploymentFolder -rootPath $ServiceGroupRoot -subdirectory 'Parameters'
$Template_path = Create-DeploymentFolder -rootPath $ServiceGroupRoot -subdirectory 'Templates'

$ExtensionInfoFileName = Split-Path -Path $ExtensionInfoFile -Leaf

$ExtensionInfoXmlContent = New-Object xml
$ExtensionInfoXmlContent = [xml](Get-Content $ExtensionInfoFile -Encoding UTF8)

# Validate the XML file
Validate-ExtensionInfoFile -ExtnInfoXml $ExtensionInfoXmlContent -UseBuildVersionForExtnVersion $UseBuildVersionForExtnVersion

# Add build version file. This is the build version and Not Extension version
if(!$BuildVersion)
{
    $BuildVersion = "1.0.0.0"
}
$buildVersionFile = Join-Path -Path $ServiceGroupRoot -ChildPath 'buildver.txt'
$BuildVersion | Out-File $buildVersionFile -Encoding utf8 -Force

# Update the xml content
# If build number must be used as extension version, then it must be updated in the extensionInfo xml file.
# The file must be copied to the Parameters folder. This is used for as parameter for Register operation
$ExtensionInfoXmlContent.ExtensionInfo.ExtensionImage.Version = Get-ExtensionVersion -ExtnInfoXml $ExtensionInfoXmlContent -UseBuildVersionForExtnVersion $UseBuildVersionForExtnVersion -BuildVersion $BuildVersion

# Update the zip file name in the xml file. This value is not used in the operation, but if this value is not updated, it will confuse while debugging any issue
# The value in the parameter file is used in the operations
$ExtensionInfoXmlContent.ExtensionInfo.PipelineConfig.ExtensionZipFileName = Get-ZipfileName -ExtnInfoXml $ExtensionInfoXmlContent `
                                                                                                -ReplaceBuildVersionInFileName $ReplaceBuildVersionInFileName `
                                                                                                -ReplaceExtensionVersionInFileName $ReplaceExtensionVersionInFileName `
                                                                                                -BuildVersion $BuildVersion `
                                                                                                -ExtnVersion $ExtensionInfoXmlContent.ExtensionInfo.ExtensionImage.Version

# Generate the Parameter file
$paramsFileName = 'ArmParameters.json'
$ParameterFile = Join-Path $Param_path -ChildPath $paramsFileName
[string] $Parameter_Template_File = Get-ParameterFileTemplate
$Parameter_Template_File | Out-File $ParameterFile -Encoding utf8 -Force

# Generate the Template file
$void = Get-TemplateFile -TemplateFilePath $Template_path -TemplateFileName "UpdateConfig.Template.json"

$RolloutTypes = $ExtensionInfoXmlContent.ExtensionInfo.PipelineConfig.RolloutTypes
foreach ($CloudType in $ExtensionInfoXmlContent.ExtensionInfo.CloudTypes.ChildNodes)
{
    $CloudName =  $CloudType.Name

    Get-RolloutParameterFile -ServiceGroupRoot "$($ServiceGroupRoot)" -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent -ExtensionInfoFileName $ExtensionInfoFileName

    Get-ServiceModelFile -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent
    
    Get-AllRolloutSpecFiles -ServiceGroupRoot $ServiceGroupRoot -CloudName $CloudName -ExtnInfoXml $ExtensionInfoXmlContent -RolloutTypes $RolloutTypes
}

# save the file in Parameters folder, with encoding
$outputExtensionInfoXmlFile = Join-Path -Path $Param_path -ChildPath $ExtensionInfoFileName

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
$sw = New-Object System.IO.StreamWriter($outputExtensionInfoXmlFile, $false, $utf8WithoutBom)

$ExtensionInfoXmlContent.Save($sw)
$sw.Close()