Function Get-SADomainController
{
    <#
    .SYNOPSIS
        Get a list of domain controllers
    .DESCRIPTION
        Will provide a list of domain controllers in your current domain. Optionally you can also 
        request a discovery of the "closest" one.
    .PARAMETER ComputerName
        Retrieve information about the specified domain controller.  This is a RegEx match so you can
        match multiple domain controllers with your pattern.
    .PARAMETER Discover
        Use Discover to return the information of the closest domain controller.
    .EXAMPLE
        Get-SADomainController

        Retrieve a list of all domain controllers in your domain.
    .EXAMPLE
        Get-SADomainController -Computer 01

        Retrieve a list of all domain controlelrs with "01" in their name.
    .EXAMPLE
        Get-SADomainController -Discover
    
        Retrieve the name of the closest domain controller.
    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            05/27/19        Initial Release
    .LINK
        https://github.com/martin9700/SimpleADAdmin
    #>
    [CmdletBinding(DefaultParameterSetName="all")]
    Param (
        [Parameter(Position=0,ParameterSetName="dc")]
        [string]$ComputerName,

        [Parameter(ParameterSetName="all")]
        [switch]$Discover
    )

    Begin {
        Write-Verbose "$(Get-Date): Get-SADomainController beginning"
        $DirectoryContext = [System.DirectoryServices.ActiveDirectory.DirectoryContext]::New("Domain")
        $SelectProperties = "Name","Forest","Domain","SiteName","Roles","CurrentTime","HighestCommittedUsn","OSVersion"
    }

    Process {
        If ($Discover)
        {
            $LocatorFlag = [System.DirectoryServices.ActiveDirectory.LocatorOptions]::ForceRediscovery
            [System.DirectoryServices.ActiveDirectory.DomainController]::FindOne($DirectoryContext, $LocatorFlag) | Select-Object $SelectProperties
        }
        ElseIf ($ComputerName)
        {
            [System.DirectoryServices.ActiveDirectory.DomainController]::FindAll($DirectoryContext) | Where-Object Name -match $ComputerName | Select-Object $SelectProperties
        }
        Else
        {
            [System.DirectoryServices.ActiveDirectory.DomainController]::FindAll($DirectoryContext) | Select-Object $SelectProperties
        }
    }

    End {
        Write-Verbose "$(Get-Date): Get-SADomainController completed"
    }
}