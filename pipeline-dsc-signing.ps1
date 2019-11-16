Add-Type -Assembly System.IO.Compression.FileSystem

Function ExtractFileFromZip ($ZIPFileName,$destPath,$pattern)
{
	try
    {

	    $zip = [IO.Compression.ZipFile]::OpenRead($ZIPFileName)
        
        $entries=$zip.Entries | where {$_.FullName -like $pattern} 

        $entries | foreach {
            Write-Host "Entry: " $_.Name
            $outputPath= Join-Path $destPath $_.Name
            [IO.Compression.ZipFileExtensions]::ExtractToFile( $_, $outputPath, $true)
        }

	    $zip.Dispose()
	} catch {
        Write-Warning "Failed to extract $ZIPFileName to $destPath. Details : $_"
        $zip.Dispose()
	}
}

$pipelinePath = Join-Path .\ pipeline-signing

$workingPath = $(Resolve-Path $pipelinePath)
Write-Host "pipelinePath = ${workingPath}"

$dscPath = Join-Path $workingPath "dsc"
Write-Host "dscPath = ${dscPath}"

$signingPath = Join-Path $dscPath "signing"
Write-Host "signingPath = ${signingPath}"


# 
$files = Get-ChildItem $dscPath -Filter *.zip
for ($i=0; $i -lt $files.Count; $i++) {
    $moduleFilePath = $files[$i].FullName
    $moduleName = $files[$i].BaseName.split("_")[0]
    $newModuleFilePath = $moduleName + ".zip"

    Write-Host "Extracting '*.sha256sums' to $signingPath path..." 
    ExtractFileFromZip $moduleFilePath $signingPath "*.sha256sums"

    Write-Host "Renaming '${moduleFilePath}' to zip '${moduleName}'..." 
    Rename-Item -Path $moduleFilePath -NewName $newModuleFilePath
}

Write-Host "Renaming all *.sha256sums to *.asc ..."
Get-ChildItem -Path $signingPath\*.sha256sums | rename-item -NewName {$_.name -replace ".sha256sums",".asc"}