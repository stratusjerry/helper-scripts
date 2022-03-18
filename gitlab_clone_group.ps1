# Git clone all the repos under an Group
# TODO: add Group name lookup resolve to number
$group = "470642"  # Inkscape:470642 ; gitlab-org:9970
$skipLocal = $true
$baseURL = "https://gitlab.com/"

# Fix for Powershell default to TLSv1.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = "Tls11, Tls12"
# Speedup Downloads
$ProgressPreference = 'SilentlyContinue'

$groupURL = $baseURL + "api/v4/groups/" + $group
$groupProjURL = $groupURL + "/projects"
$subDirs = Get-ChildItem -Directory -Name

$reqGroupProj = Invoke-WebRequest -Uri $groupProjURL
# Without auth, Gitlab only returns public repos
$repos = $reqGroupProj.Headers.'X-Total'
$pageCount = 0; $repoCount = 0 $skippedLocal = 0 #; $perPage = 20
if ($reqGroupProj.StatusCode -eq 200){
# TODO: Next Page Logic: if ($reqGroupProj.Headers.'X-Next-Page'){write-host "yes"}
#Do {
    #$pageCount += 1
    $reqGroupProjJson = ConvertFrom-Json ($reqGroupProj.Content)
    #$reqGroupProjJson = ConvertFrom-Json $([String]::new($reqGroupProj.Content)) #This is nicer
    foreach ($item in $reqGroupProjJson){
        $repoCount += 1
        $URL = $item.http_url_to_repo # .ssh_url_to_repo
        if ($skipLocal){
            $localDir = $item.path
            if ($subDirs){
                if ( $subDirs.Contains($localDir) ){
                    Write-Host "($repoCount / $repos) Skipping Local: $localDir" -ForegroundColor Red
                    $skippedLocal += 1
                    continue
                }
            }
        }
        Write-Host "($repoCount / $repos) Cloning: $URL" -ForegroundColor Green
        git clone $URL
    }
#} While ( $nextPage = $reqGroupProj.Headers.'X-Next-Page' )
}
