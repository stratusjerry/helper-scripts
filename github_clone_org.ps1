# Git clone all the repos under an Organization/User
$org = "GoogleContainerTools"

# Fix for Powershell default to TLSv1.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

$pageCount = 1; $perPage = 100
Do {
    $pagedURL = "https://api.github.com/orgs/" + $org + "/repos?page=" + $pageCount + "&per_page=" + $perPage
    $request = Invoke-WebRequest -Uri $pagedURL
    $reqJson = ConvertFrom-Json ($request.Content)
    #$reqJson = ConvertFrom-Json $([String]::new($request.Content)) #This is nicer
    foreach ($item in $reqJson){
        $URL = $item.clone_url
        Write-Host "Cloning: $URL" -ForegroundColor Green
        git clone $URL
    }
    $pageCount += 1
} While ( $request.Headers.Link.Contains("next") )
