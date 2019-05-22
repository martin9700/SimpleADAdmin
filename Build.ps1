[CmdletBinding()]
Param()

$ModuleName = "SimpleADAdmin"

#
# Grab nuget bits, install modules, start build.
#
Write-Verbose -Verbose -Message "$(Get-Date): Preparing environment"
$Stopwatch = [system.diagnostics.stopwatch]::StartNew()

Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Import-Module PowerShellGet -ErrorAction Stop
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Install-Module Pester,PSScriptAnalyzer,PSModuleBuild



#
# Build the module
#
$ModuleInformation = @{
    Path            = "$ENV:APPVEYOR_BUILD_FOLDER\Source"
    TargetPath      = "$ENV:APPVEYOR_BUILD_FOLDER\$ModuleName"
    ModuleName      = "SimpleADAdmin"
    ReleaseNotes    = (git log -1 --pretty=%s) | Out-String
    Author          = "Martin Pugh (@TheSurlyAdm1n)"
    ModuleVersion   = $ENV:APPVEYOR_BUILD_VERSION
    Company         = "www.thesurlyadmin.com"
    Description     = "Active Directory Administration made easy, without the need for RSAT"
    ProjectURI      = "https://github.com/martin9700/$ModuleName"
    LicenseURI      = "https://github.com/martin9700/$ModuleName/blob/master/LICENSE"
    PassThru        = $true
}
Invoke-PSModuleBuild @ModuleInformation




#
# Analyse source
#
Write-Verbose -Verbose -Message "$(Get-Date): Analyzing code"
$Results = Invoke-ScriptAnalyzer -Path "$ENV:APPVEYOR_BUILD_FOLDER\$ModuleName" -Severity "Warning" -Recurse
$Results | Format-Table

$Errors = $Results | Where-Object Severity -eq "Error"
If ($Errors)
{
    Write-Error "$(Get-Date): One or more Script Analyzer errors/warnings where found. Build cannot continue!" -ErrorAction Stop
}

Write-Verbose "$(Get-Date): Script passed"


#
# Run tests
#
$TestResults = Invoke-Pester -PassThru -OutputFormat NUnitXml -OutputFile ".\TestResults.xml"
(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",(Resolve-Path ".\TestResults.xml"))
    
If ($TestResults.FailedCount -gt 0)
{
    $TestResults | Format-List *
    Write-Error "$(Get-Date): Failed '$($TestResults.FailedCount)' tests, build failed" -ErrorAction Stop
}


#
# Publish module
#
If ($ENV:PSGalleryAPIKey)
{
    $PublishInformation = @{
        Path            = "$ENV:APPVEYOR_BUILD_FOLDER\$ModuleName"
        Force           = $true
        NuGetApiKey     = $ENV:PSGalleryAPIKey
    }

    Try {
        Write-Verbose "$(Get-Date):" -Verbose
        Write-Verbose "$(Get-Date): Merge detected, publishing $ModuleName to Microsoft" -Verbose
        Publish-Module @PublishInformation -ErrorAction Stop -Verbose
        Write-Host "`n`nPublish to PSGallery successful" -ForegroundColor Green
    }
    Catch {
        Write-Error "Publish to PSGallery failed because ""$_""" -ErrorAction Stop
    }
}
Else
{
    Write-Warning "$(Get-Date): Pull request detected, no publish needed"
}

#
# Completed
#
$Stopwatch.Stop()
Write-Verbose -Verbose -Message "$(Get-Date): Build completed in $($Stopwatch.Elapsed)"