Add-Type -Assembly System.IO.Compression.FileSystem

Function AddtoExistingZip ($ZIPFileName,$newFileToAdd,$target)
{
	try
    {
        $fileName = [System.IO.Path]::GetFileName($newFileToAdd)       
	    [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
	    $zip = [System.IO.Compression.ZipFile]::Open($ZIPFileName,"Update")
	    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$newFileToAdd,$target,"Optimal") | Out-Null
	    $zip.Dispose()
	} catch {
		Write-Warning "Failed to add $NewFileToAdd to $ZIPFileName . Details : $_"
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

Xcopy $dscPath\*.zip $signingPath /Y /M

dir $signingPath

$files = Get-ChildItem $signingPath -Filter *.zip
for ($i=0; $i -lt $files.Count; $i++) {
    $zipPath = $files[$i].FullName
    $moduleName = $files[$i].BaseName
    $fileName = $files[$i].BaseName + ".asc"
    $signedFilePATH = Join-Path $signingPath $fileName
    Write-Host "Adding signed file '${fileName}' to '${zipPath}'..."
    $targetPath = $moduleName + "/" + $fileName
    AddtoExistingZip $zipPATH $signedFilePATH $targetPath
    rm $signedFilePATH
}