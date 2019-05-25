Class SAGroup
{
    [string]   $Name
    [string]   $SamAccountName
    [string]   $Description
    [string]   $Info
    [string]   $Email
    [string]   $DistinguishedName
    [guid]     $ObjectGUID
    [string]   $ObjectSID
    [string[]] $MemberOf
    [string[]] $Members
    [string]   $ManagedBy
    [string]   $GroupCategory
    [string]   $GroupScope
    [datetime] $WhenCreated
    
    SAGroup ()
    {
        Write-Error "You must specify the SamAccountName of the group you want to look at" -ErrorAction Stop
    }

    SAGroup ( [string]$Identity )
    {
        $Searcher = [ADSISearcher]"(&(objectClass=group)(samAccountName=$Identity))"
        $Found = @($Searcher.FindOne())

        If ($null -eq $Found.properties.samaccountname)
        {
            Write-Error "Unable to find ""$Identity""" -ErrorAction Stop
        }
        $this.SamAccountName       = $Found.properties.samaccountname | Select-Object -First 1

        $this.EnumerateFields()

        $this | Add-Member -MemberType ScriptProperty -Name LastModified -Value {
            $Searcher = [ADSISearcher]"(&(objectClass=group)(samAccountName=$($this.SamAccountName)))"
            $Found = $Searcher.FindOne()

            # Enumerate LastModified
            Write-Output $Found.properties.whenchanged | Select-Object -First 1

            $this.EnumerateFields()
        }

        $DefaultDisplayProperties = @(
            "Name"
            "SamAccountName"
            "Description"
            "Info"
            "Email"
            "DistinguishedName"
            "ObjectGUID"
            "ObjectSID"
            "MemberOf"
            "Members"
            "ManagedBy"
            "GroupCategory"
            "GroupScope"
            "WhenCreated"
            "LastModified"
        )
        $this | Add-Member -Force -MemberType MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]$DefaultDisplayProperties)))

    }

    hidden [void] EnumerateFields()
    {
        $Searcher = [ADSISearcher]"(&(objectClass=group)(samAccountName=$($this.SamAccountName)))"
        $Found = @($Searcher.FindOne())

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
        
        $this.Name                 = $Found.properties.name | Select-Object -First 1
        $this.Description          = $Found.properties.description | Select-Object -First 1
        $this.Info                 = $Found.properties.info | Select-Object -First 1
        $this.Email                = $Found.properties.mail | Select-Object -First 1
        $this.DistinguishedName    = $Found.properties.distinguishedname | Select-Object -First 1
        $this.ObjectGUID           = New-Object GUID(,($Found.properties.objectguid | Select-Object -First 1))
        $this.ObjectSID            = (New-Object System.Security.Principal.SecurityIdentifier(($Found.properties.objectsid | Select-Object -First 1),0)).Value
        $this.MemberOf             = $Found.properties.memberof
        $this.Members              = $Found.properties.member
        $this.ManagedBy            = $Found.properties.managedby | Select-Object -First 1
        $this.GroupCategory        = $GroupTypes[($Found.properties.grouptype | Select-Object -First 1)].Category
        $this.GroupScope           = $GroupTypes[($Found.properties.grouptype | Select-Object -First 1)].Scope
        $this.WhenCreated          = $Found.properties.whencreated | Select-Object -First 1
    }

    hidden [PSCustomObject[]] GetMemberObject([string]$dn, [boolean]$Recurse)
    {
        $Results = New-Object -TypeName System.Collections.ArrayList
        $Searcher = [ADSISearcher]"((distinguishedName=$dn))"
        $Found = @($Searcher.FindOne())
        If ($Found.Count -eq 0)
        {
            Write-Warning "Unable to find ""$dn"""
        }
        Else
        {
            If (($Found.properties.objectclass | Select-Object -Last 1) -eq "group" -and $Recurse)
            {
                $subResults = $this.GetMembersFromGroup($dn)
                ForEach ($Result in $subResults)
                {
                    $null = $Results.Add($Result)
                }
            }
            Else
            {
                $null = $Results.Add([PSCustomObject]@{
                    Member         = $Found.properties.name | Select-Object -First 1
                    SamAccountName = $Found.properties.samaccountname | Select-Object -First 1
                    ObjectClass    = $Found.properties.objectclass | Select-Object -Last 1
                })
            }
        }
        Return $Results
    }

    hidden [PSCustomObject[]] GetMembersFromGroup ([string]$dn)
    {
        $Results = $null
        $Searcher = [ADSISearcher]"((distinguishedName=$dn))"
        $Found = @($Searcher.FindOne())
        If ($Found.Count -eq 0)
        {
            Write-Warning "Unable to find ""$dn"""
        }
        Else
        {
            $Results = ForEach ($Member in ($Found.properties.member))
            {
                $this.GetMemberObject($Member, $true)
            }
        }

        Return $Results
    }

    [PSCustomObject[]] GetMembers()
    {
        $Results = ForEach ($Member in $this.Members)
        {
            $this.GetMemberObject($Member, $false)
        }
        Return $Results
    }

    [PSCustomObject[]] GetMembersRecursive()
    {
        $Results = ForEach ($Member in $this.Members)
        {
            $this.GetMemberObject($Member, $true)
        }
        Return $Results
    }
}
