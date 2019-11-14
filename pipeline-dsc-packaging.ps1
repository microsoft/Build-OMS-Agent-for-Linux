# Add file to existing zip-file
Function AddtoExistingZip ($ZIPFileName,$newFileToAdd)
{
	try
    {
        $fileName = [System.IO.Path]::GetFileName($newFileToAdd)       
	    [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
	    $zip = [System.IO.Compression.ZipFile]::Open($ZIPFileName,"Update")
	    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$newFileToAdd,$fileName,"Optimal") | Out-Null
	    $zip.Dispose()
	} catch {
        $zip.Dispose()
		Write-Warning "Failed to add $NewFileToAdd to $ZIPFileName . Details : $_"
	}
}

$pipelinePath=.\pipeline-signing

$workingPath = $(Resolve-Path $pipelinePath)
Write-Host "pipelinePath = ${workingPath}"

$dscPath = Join-Path $workingPath "dsc"
Write-Host "dscPath = ${dscPath}"

$signingPath = Join-Path $dscPath "signing"
Write-Host "signingPath = ${signingPath}"

Write-Host "Renaming *.sha256sums to *.asc"
Get-ChildItem -Path $signingPath\*.sha256sums | rename-item -NewName {$_.name -replace ".sha256sums",".asc"}


Xcopy $dscPath\*.zip $signingPath /Y /M

dir $signingPath

$files = Get-ChildItem $signingPath -Filter *.zip
for ($i=0; $i -lt $files.Count; $i++) {
    $zipPath = $files[$i].FullName
    $fileName = $files[$i].BaseName + ".asc"
    $signedFilePATH = Join-Path $signingPath $fileName
    Write-Host "Adding Existing file '${fileName}' to zip '${zipPath}'..." 
    AddtoExistingZip $zipPATH $signedFilePATH   
}