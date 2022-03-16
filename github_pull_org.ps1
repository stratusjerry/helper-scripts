# Take the Git cloned repos under an Organization/User and check pushed_at (not updated_at) newer then local copy and git pull new version
$org = "GoogleContainerTools"
$sortOn = "pushed"  # created, updated, pushed, full_name
$doPull = $True
#$skipLocal = $true

# Fix for Powershell default to TLSv1.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = "Tls11, Tls12"
# Speedup Downloads
$ProgressPreference = 'SilentlyContinue'

$subDirs = Get-ChildItem -Directory #-Name
# We could use below logic to check for new repos not local
#$userURL = "https://api.github.com/users/" + $org
#$reqUser = Invoke-RestMethod $userURL
#$repos = $reqUser.public_repos
$pageCount = 0; $perPage = 100; $repoCount = 0
# TODO: verify local LastWriteTime directory gets updated after 'git pull'
# TODO: add Do while logic to check if more than 1 page
#Do {
    $pageCount += 1
    $pagedURL = "https://api.github.com/orgs/" + $org + "/repos?page=" + $pageCount + "&per_page=" + $perPage + "&sort=" + $sortOn
    $request = Invoke-WebRequest -Uri $pagedURL
    $reqJson = ConvertFrom-Json ($request.Content)
    #$reqJson = ConvertFrom-Json $([String]::new($request.Content)) #This is nicer
    $updatedRepo = 0
    foreach ($item in $reqJson){
        $repoCount += 1
        $URL = $item.clone_url
        #if ($skipLocal){
        $localDir = $URL -replace "https://github.com/$org/(.*)\.git",'$1'
        if ($foundSubDir = $subDirs | Where-Object -Property Name -eq -Value $localDir){
            Write-Host "($repoCount) found local folder: $localDir"
            try {
                $remoteUpdatedAt = Get-Date -Date $item.pushed_at
            }
            catch {
                Write-Host "    Unable to convert date" -ForegroundColor Red
                pause
                continue
            }

            if ($foundSubDir.LastWriteTime -lt $remoteUpdatedAt){
                [String]::($remoteUpdatedAt)
                Write-Host "    Local Dir" $foundSubDir.LastWriteTime "older than:" $remoteUpdatedAt.ToString() "updating" -ForegroundColor Green
                $updatedRepo += 1
                if ($doPull){
                    cd $localDir
                    git pull
                    cd ..
                }
            } else {
                Write-Host "    Local Dir" $foundSubDir.LastWriteTime "NOT older than:" $remoteUpdatedAt.ToString() "no operations"
                #pause
                # Should we continue here? Found some repos might have newer "pushed_at" without newer content (does something like a branch deletion update this?)
                #break
            }
        } else {
            Write-Host "No Local Folder: $localDir" -ForegroundColor Red
            pause
            # Should we 'git clone' here?
            continue
        }
    }
#} While ( $request.Headers.Link.Contains("next") )
