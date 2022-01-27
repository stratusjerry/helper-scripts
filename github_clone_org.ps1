# Git clone all the repos under an Organization/User
$org = "GoogleContainerTools"
$skipLocal = $true

# Fix for Powershell default to TLSv1.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

$subDirs = Get-ChildItem -Directory -Name
$userURL = "https://api.github.com/users/" + $org
$reqUser = Invoke-RestMethod $userURL
$repos = $reqUser.public_repos
$pageCount = 0; $perPage = 100; $repoCount = 0
Do {
    $pageCount += 1
    $pagedURL = "https://api.github.com/orgs/" + $org + "/repos?page=" + $pageCount + "&per_page=" + $perPage
    $request = Invoke-WebRequest -Uri $pagedURL
    $reqJson = ConvertFrom-Json ($request.Content)
    #$reqJson = ConvertFrom-Json $([String]::new($request.Content)) #This is nicer
    foreach ($item in $reqJson){
        $repoCount += 1
        $URL = $item.clone_url
        if ($skipLocal){
            $localDir = $URL -replace "https://github.com/$org/(.*)\.git",'$1'
            if ( $subDirs.Contains($localDir) ){
                Write-Host "($repoCount / $repos) Skipping Local: $localDir" -ForegroundColor Red
                continue
            }
        }
        Write-Host "($repoCount / $repos) Cloning: $URL" -ForegroundColor Green
        git clone $URL
    }
} While ( $request.Headers.Link.Contains("next") )
