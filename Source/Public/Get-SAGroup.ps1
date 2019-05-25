Function Get-SAGroup {
    <#
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [Alias("Group","SamAccountName","Name")]
        [string]$Identity,
        [string[]]$DefaultDisplayProperties = @("Name","SamAccountName","Description","DistinguishedName","GroupCategory","GroupScope")
    )

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
            #Found more than one, need to select which one you want
            $Selected = $Found | 
                Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},
                    @{Name="DisplayName";Expression={ $_.properties.displayname }},
                    @{Name="Description";Expression={ $_.properties.description }} | 
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

    #Thanks Richard Siddaway for breaking this out
    $GroupTypes = @{
        2           = [PSCustomObject]@{Category="Distribution";Scope="Global"}
        4           = [PSCustomObject]@{Category="Distribution";Scope="DomainLocal"}
        8           = [PSCustomObject]@{Category="Distribution";Scope="Universal"}
        -2147483646 = [PSCustomObject]@{Category="Security";Scope="Global"}
        -2147483644 = [PSCustomObject]@{Category="Security";Scope="DomainLocal"}
        -2147483643 = [PSCustomObject]@{Category="Security";Scope="BuiltinLocal"}
        -2147483640 = [PSCustomObject]@{Category="Security";Scope="Universal"}
    }
    
    $Global:SAGroup = [PSCustomObject]@{
        Name                 = $Found.properties.name | Select -First 1
        SamAccountName       = $Found.properties.samaccountname | Select -First 1        
        Description          = $Found.properties.description | Select -First 1
        Info                 = $Found.properties.info | Select -First 1
        Email                = $Found.properties.mail | Select -First 1
        DistinguishedName    = $Found.properties.distinguishedname | Select -First 1
        ObjectGUID           = New-Object GUID(,($Found.properties.objectguid | Select -First 1))
        ObjectSID            = (New-Object System.Security.Principal.SecurityIdentifier(($Found.properties.objectsid | Select -First 1),0)).Value
        MemberOf             = $Found.properties.memberof
        Members              = $Found.properties.member
        ManagedBy            = $Found.properties.managedby | Select -First 1
        GroupCategory        = $GroupTypes[($Found.properties.grouptype | Select -First 1)].Category
        GroupScope           = $GroupTypes[($Found.properties.grouptype | Select -First 1)].Scope
        WhenCreated          = $Found.properties.whencreated | Select -First 1
    }

    #Display default properties
    $SAGroup | Add-Member -Force -MemberType MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]$DefaultDisplayProperties)))

    #Last modified, and dynamic fields
    $SAGroup | Add-Member -MemberType ScriptProperty -Force -Name LastModified -Value {
        $Searcher = [ADSISearcher]"(&(objectClass=group)(samAccountName=$($this.SamAccountName)))"
        $Found = $Searcher.FindOne()

        $Found.properties.whenchanged | Select -First 1
        $this.MemberOf  = $Found.properties.memberof
        $this.Members   = $Found.properties.member
    }
}
