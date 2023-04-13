$remove_list = @(
  "Microsoft.BingWeather",
  "Microsoft.GetHelp",
  "Microsoft.Getstarted",
  "Microsoft.Messaging",
  "Microsoft.Microsoft3DViewer",
  "Microsoft.MicrosoftOfficeHub",
  "Microsoft.MicrosoftSolitaireCollection",
  "Microsoft.MixedReality.Portal",
  "Microsoft.Office.OneNote",
  "Microsoft.OneConnect",
  "Microsoft.People",
  "Microsoft.Print3D",
  "Microsoft.SkypeApp",
  "Microsoft.Wallet",
  "Microsoft.WindowsAlarms",
  #"Microsoft.WindowsCalculator",
  #"Microsoft.WindowsCamera",
  #"Microsoft.WindowsSoundRecorder",
  "microsoft.windowscommunicationsapps",
  "Microsoft.WindowsFeedbackHub",
  "Microsoft.WindowsMaps",
  "Microsoft.Xbox.TCUI",
  "Microsoft.XboxApp",
  "Microsoft.XboxGameOverlay",
  "Microsoft.XboxGamingOverlay",
  "Microsoft.XboxIdentityProvider",
  "Microsoft.XboxSpeechToTextOverlay",
  "Microsoft.YourPhone",
  "Microsoft.ZuneMusic",
  "Microsoft.ZuneVideo"
)

$script:Provisioned = Get-AppxProvisionedPackage -Online
$script:AppxPackages = Get-AppxPackage

function Get-Element {
	param(
		[Parameter(Mandatory)]
		$Array,
        [Parameter(Mandatory)]
		$ArrayField,
		[Parameter(Mandatory)]
		$elemName,
        $returnProperty
	)

    foreach ($arrayItem in $Array){
        if ($arrayItem.$ArrayField -eq $elemName){
            $value = $arrayItem.$returnProperty
        }
    }
    return $value
}


foreach ($remove_item in $remove_list){
    # $remove_item = "Microsoft.BingWeather"
    if ($script:AppxPackages.Name -contains $remove_item){
        Write-Host "AppxPackages: $remove_item found, removing" -ForegroundColor Green
        $fullName = Get-Element -Array $script:AppxPackages -ArrayField "Name" -elemName $remove_item -returnProperty "PackageFullName"
        Write-Host "   Removing $fullName" -ForegroundColor White
        Remove-AppxPackage -PackageName $fullName  # -AllUsers
    } Else { Write-Host "AppxPackages Failed to find: $remove_item" -ForegroundColor Red }

    if ($script:Provisioned.DisplayName -contains $remove_item){
        Write-Host "AppxProvisionedPackage: $remove_item found, removing" -ForegroundColor Green
        $packageName = Get-Element -Array $script:Provisioned -ArrayField "DisplayName" -elemName $remove_item -returnProperty "PackageName"
        Write-Host "   Removing $packageName" -ForegroundColor White
        Remove-AppxProvisionedPackage -Online -Package $packageName -AllUsers
    } Else { Write-Host "AppxProvisionedPackage Failed to find: $remove_item" -ForegroundColor Red }
}

