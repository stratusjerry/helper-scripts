$source_dir = "C:\Users\Foo"
$dest_dir = "C:\Users\Bar"

$RemoveSource = "True"; $RemoveSourceEmptyDirs = "True"
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
                if ($RemoveSource -eq "True"){ Remove-Item $sourceObj.FullName }
            } else {
                $missHash += 1
                Write-Host "   Hash Miss" -ForegroundColor Red
            }
        }
    }
}

if ($RemoveSourceEmptyDirs -eq "True"){
    do {
        $foundToDel = 0
        $loopCount += 1
        # -Force Gets Hidden files, need to start with child folders first (tail recursion)
        $srcPaths = Get-ChildItem -LiteralPath $source_dir -Recurse -Force -Directory
        $sortedsrcPaths = $srcPaths | Sort-Object -Property FullName -Descending
        foreach ($sortedsrcPath in $sortedsrcPaths){
            if (! $sortedsrcPath.GetDirectories() ){
                if ($sortedsrcPath.GetFiles().Count -eq 0){
                    $foundToDel = 1
                    Write-Host $sortedsrcPath.FullName has no child dirs or files, deleting -ForegroundColor Red
                    Remove-Item $sortedsrcPath.FullName
                    sleep 1
                }
            }
        }
        sleep 3
        } until ($foundToDel -eq 0)
        
    Write-Host Delete took $loopCount loops
}
