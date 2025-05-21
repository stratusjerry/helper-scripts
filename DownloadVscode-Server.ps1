$dlDir = "D:\Users\your\path\" # Must contain backslash
$indexFile = "index.txt"
$vscodeVers = @()
$expectedFileName = "vscode-server-linux-x64.tar.gz"
$htmlTagURL = "https://github.com/microsoft/vscode/releases/tag/"
# Fix a TLS issue
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Speedup Downloads
$ProgressPreference = 'SilentlyContinue'
$tagArray = @()
$useAuth = $false
$debug = $true
$sleepTime = 1

if ($useAuth){
    $params = @{ 'AccessToken' = "EDIT" }
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "token EDIT")
    $headers.Add("Accept", "application/vnd.github.VERSION.raw")
}

function Write-IfDebug {
    param (
        [string]$Message,
        [ConsoleColor]$ForegroundColor
    )

    if ($debug) {
        if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
            Write-Host $Message -ForegroundColor $ForegroundColor
        } else {
            Write-Host $Message
        }
    }
}

function Write-Failure {
    param (
        [string]$FailMessage
    )

    Write-Host $FailMessage -ForegroundColor Red
    pause
}

$getReleases = Invoke-RestMethod "https://api.github.com/repos/microsoft/vscode/releases" -Headers $headers #Max 100 default 30
## This request example matches the issue we're seeing with wrong sha returned
#$getDebug = Invoke-RestMethod "https://api.github.com/repos/microsoft/vscode/git/refs/tags/1.61.2" -Headers $headers
## Testing different API call here
#$getReleases[0] ; $getReleases[0].assets_url #https://api.github.com/repos/microsoft/vscode/releases/51646803
#$getReleases[0].url #"https://api.github.com/repos/microsoft/vscode/releases/51646803/assets"
#$tagged = Invoke-RestMethod "https://api.github.com/repos/microsoft/vscode/git/tags/10e7355fd691a471ff95902180c81898aea2069c" -Headers $headers
#$tagged.sha # 10e7355fd691a471ff95902180c81898aea2069c
#$taggedRelease = Invoke-RestMethod "https://api.github.com/repos/microsoft/vscode/releases/tags/1.61.2" -Headers $headers
$tagName = ""; $verCommitHash = @{}
foreach ($getRelease in $getReleases){
    $tagName = $getRelease.tag_name
    $tagArray += $tagName
}

foreach ($tagItem in $tagArray){
    $htmlURL = $htmlTagURL + $tagItem
    Write-IfDebug "Checking Tag: ${tagItem}  URL: ${htmlURL}"
    ## $getTag.object.sha doesn't always equal release commit ID and can return commitIDs that don't exist in the code base. Only 
    ##  reliable way to get the release CommitID (we use this to get vscode-server version) involves parsing the HTML page:
    #$getTag = Invoke-RestMethod "https://api.github.com/repos/microsoft/vscode/git/refs/tags/$tagItem" -Method 'GET' -Headers $headers
    #Write-Host "Tag: $tagItem CommitID: " $getTag.object.sha
    #$vscodeVers += $getTag.object.sha
    $taggedReleaseNoAPI = Invoke-WebRequest $htmlURL #"https://github.com/microsoft/vscode/releases/tag/1.61.2"
    ## These other methods fail:
    #   $taggedRelease = Invoke-RestMethod "https://api.github.com/repos/microsoft/vscode/releases/tags/1.61.2" -Headers $headers
    #   $taggedRelease.html_url # Versus $taggedRelease.url, also $taggedRelease.assets_url returns null
    #$allLinks = $taggedReleaseNoAPI.ParsedHtml.links | Select href #This is a slower method
    $allLinksHref = $taggedReleaseNoAPI.Links | Select-Object href
    $linkCounter = 0; $linkMatch = 0; $tagSHA = ""
    foreach ($allLinkHref in $allLinksHref){
        $linkCounter++
        if ($allLinkHref.href.Contains("vscode/commit/") ){
            Write-IfDebug "  counter: ${linkCounter} of $($allLinksHref.count)"
            Write-IfDebug "    href: ${allLinkHref}"
            $tagSHA = $allLinkHref.href -Replace '.*commit/'
            Write-Host "Tag: $tagItem CommitID: $tagSHA"
            $linkMatch++
        }
    }
    if ($linkMatch -eq 0) { Write-Failure "  Failed to find commit link"
    } elseif ($linkMatch -gt 1 ) { Write-Failure "  Found multiple commit links" }
    if ($tagSHA -eq "") { Write-Failure "  Failed to find tagSHA" }
    $vscodeVers += $tagSHA
    $verCommitHash.Add($tagItem, $tagSHA)
    Start-Sleep $sleepTime #So we don't do a request flood
}

$dlProcessed = 0; $dlCount = 0
foreach ($vscodeVer in $vscodeVers){
    $dlProcessed++
    $verPath = $dlDir + $vscodeVer + "\"
    $filePath = $verPath + $expectedFileName
    $weblink = "https://update.code.visualstudio.com/commit:${vscodeVer}/server-linux-x64/stable"
    if ( !(test-path $verPath) ) {
        Write-Host "Creating directory: $verPath"
        New-Item -ItemType Directory -Force -Path $verPath
    }
    if ( !(test-path $filePath) ) {
        $dlCount++
        Write-Host "File doesn't exist, downloading ${dlProcessed} of $($vscodeVers.count) to filepath: ${filePath} "
        #Invoke-WebRequest -Uri $weblink -OutFile $verPath
        $dlFile = Invoke-WebRequest -Uri $weblink
        if ($dlFile.StatusCode -ne 200){
            Write-Host "Got an error downloading $weblink" -ForegroundColor Red
            pause
        }
        $content = [System.Net.Mime.ContentDisposition]::new($dlFile.Headers["Content-Disposition"])
        $fileName = $content.FileName
        if ($fileName -ne $expectedfileName){ 
            Write-Host "Filename: $fileName doesn't equal download file name: $expectedfileName " -ForegroundColor Red
        }
        $fullFilePath = $verPath + $fileName
        $file = [System.IO.FileStream]::new($fullFilePath, [System.IO.FileMode]::Create)
        $file.Write($dlFile.Content, 0, $dlFile.RawContentLength)
        $file.Close()
    }
    if ($debug){ pause }
    Start-Sleep $sleepTime
}

$indexFilePath = $dlDir + $indexFile

$verCommitHash.GetEnumerator() | ForEach-Object {
    "$($_.Key) = $($_.Value)"
} | Out-File -FilePath $indexFilePath -Encoding UTF8
