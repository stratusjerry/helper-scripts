$source_dir = "C:\Users\Foo"
$dest_dir = "C:\Users\Bar"


$sourceFiles = Get-ChildItem $source_dir -Recurse | where { ! $_.PSIsContainer }
$destFiles = Get-ChildItem $dest_dir -Recurse | where { ! $_.PSIsContainer }

# Compare-Object $sourceFiles $destFiles -ExcludeDifferent -IncludeEqual

$match = 0; $matchHash = 0; $missHash = 0
foreach ($sourceObj in $sourceFiles){
    $sourceShortPath = $sourceObj.FullName.Replace($source_dir,"")
    foreach ($compareObj in $destFiles){
        $compareShortPath = $compareObj.FullName.Replace($dest_dir,"")
        if ($sourceShortPath -eq $compareShortPath){
            $match += 1
            Write-Host "Match:" $compareShortPath
            $sourceHash = (Get-FileHash -Algorithm MD5 $sourceObj.FullName).Hash
            $destHash = (Get-FileHash -Algorithm MD5 $compareObj.FullName).Hash
            if ($sourceHash -eq $destHash){
                $matchHash += 1
                Write-Host "   Hash Match" -ForegroundColor Green
                Remove-Item $sourceObj.FullName
            } else {
                $missHash += 1
                Write-Host "   Hash Miss" -ForegroundColor Red
            }
        }
    }
}
