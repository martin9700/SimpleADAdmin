Function Get-SAGroup {
    <#
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,
            Position = 0)]
        [Alias("Group","SamAccountName","Name")]
        [string]$Identity
    )

    # Clear old variable
    Remove-Variable -Name SAGroup -Scope Global

    # Find the group
    $Searcher = [ADSISearcher]"(&(objectClass=group)(samAccountName=$Identity))"
    $Found = @($Searcher.FindAll())
    If ($Found.Count -ne 1)
    {
        If ($Found.Count -eq 0)
        {
            Write-Verbose "No user matching ""$Identity"", trying for a match"
            $Searcher = [ADSISearcher]"(&(objectClass=group)(name=*$Identity*))"
            $Found = @($Searcher.FindAll())
        }
        If ($Found.Count -gt 1)
        {
            # Found more than one, need to select which one you want
            $Selected = $Found | 
                Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},
                    @{Name="DisplayName";Expression={ $_.properties.displayname }},
                    @{Name="Description";Expression={ $_.properties.description }} | 
                Sort-Object -Property SamAccountName |
                Out-GridView -Title "Select the correct group" -PassThru
            If (@($Selected).Count -eq 0)
            {
                Write-Warning "No group selected"
                Return
            }
            $Searcher = [ADSISearcher]"(&(objectClass=group)(samAccountName=$($Selected.SamAccountName)))"
            $Found = $Searcher.FindOne()
        }
        ElseIf ($Found.Count -eq 0)
        {
            Write-Error "Unable to locate group matching *$Identity*" -ErrorAction Stop
        }
    }

    # Set global variable and return object
    $Global:SAGroup = [SAGroup]::New($Found.properties.samaccountname)
    Return $Global:SAGroup
}
