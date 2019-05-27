Function Get-SADomain
{
    <#
    .SYNOPSIS
        Retrieve domain information include site details
    .EXAMPLE
        Get-SADomain
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
    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose "$(Get-Date): Get-SADomain beginning"
        $SelectProperties = "Name","Forest","Parent","Children","DomainMode","DomainModeLevel","DomainControllers","PdcRoleOwner","RidRoleOwner","InfrastructureRoleOwner","Sites"
    }

    Process {
        $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $AllSites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites

        $Domain | Add-Member -MemberType NoteProperty -Name Sites -Value $AllSites

        Write-Output $Domain | Select-Object $SelectProperties
    }

    End {
        Write-Verbose "$(Get-Date): Get-SADomain completed"
    }
}