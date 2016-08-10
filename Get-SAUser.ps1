Function Get-SAUser {
    <#
    .SYNOPSIS
        athena health specific replacement for Get-ADUser
    .DESCRIPTION
        This is a more advanced version of Get-ADUser.  It allows you to see administrator specific fields in the default view, but
        also saves the user object in a global variable:

        $SAUser

        The advantage of this is if you want to do something to the object it's now persistent in your session.  Available methods are:

        AddGroup
            Usage: $SAUser.AddGroup("NameOfGroup")
        FindLockout
            Usage: $SAUser.FindLockedout()
        GetGroups
            Usage: $SAUser.GetGroups()
        GetLastLogon
            Usage: $SAUser.GetLastLogon()
        RemoveGroup
            Usage: $SAUser.RemoveGroup("NameOfGroup")
        ResetPassword
            Usage: $SAUser.ResetPassword()
                   Method will then prompt for new password
        Unlock
            Usage: $SAUser.Unlock()


        *** Requires AH.Automation Module ***

    .PARAMETER User
        Full username, or partial name of the user.  If partial all users that match will be shown in a window and you can select the
        one you want
    .INPUTS
        None
    .OUTPUTS
        $SAUser PSCustomObject
    .EXAMPLE
        Get-AHUser mpugh
        $SAUser.Unlock()

        Get user information for mpugh, see that the account is locked.  Use the Unlock() method to unlock the account.

    .EXAMPLE
        Get-AHUser Martin

        Shows a large list of users.  Select Martin Pugh
    .NOTES
        Author:             Martin Pugh
        Date:               1/15/2016
      
        Changelog:
            01/15/16        MLP - Initial Release

        Todo:
            1.    
    .LINK
    
    #>
    [CmdletBinding()]
    Param (
        [string]$User
    )

    $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$User))"
    $Found = $Searcher.FindOne()
    If ($Found.Count -eq 0)
    {
        Write-Verbose "No user matching $SAUser, trying for a match"
        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(displayName=*$User*))"
        $Found = $Searcher.FindAll()
        If ($Found.Count -gt 1)
        {
            #Found more than one, need to select which one you want
            $Selected = $Found | Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},@{Name="DisplayName";Expression={ $_.properties.displayname }} | Out-GridView -Title "Select the user you want" -PassThru
            If (@($Selected).Count -eq 0)
            {
                Write-Error "No user found, exiting" -ErrorAction Stop
            }
            $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($Selected.SamAccountName)))"
            $Found = $Searcher.FindOne()
        }
        If ($Found.Count -eq 0)
        {
            Write-Error "No user found, exiting" -ErrorAction Stop
        }
    }

    $ACCOUNTDISABLE            = 0x000002
    $DONT_EXPIRE_PASSWORD      = 0x010000
    $PASSWORD_EXPIRED          = 0x800000
    $ACCOUNT_LOCKOUT           = 16
    $ADS_UF_PASSWD_NOTREQD     = 0x0020

    $Global:SAUser = [PSCustomObject]@{
        Name = $Found.properties.displayname[0]
        SamAccountName = $Found.properties.samaccountname[0]
        Title = $Found.properties.title[0]
        Description = $Found.properties.description[0]
        GivenName = $Found.properties.givenname[0]
        Surname = $Found.properties.sn[0]
        PasswordNeverExpires = [bool]($Found.userAccountControl -band $DONT_EXPIRE_PASSWORD)
        PasswordNotRequired = [bool]($Found.userAccountControl -band $ADS_UF_PASSWD_NOTREQD)
        DistinguishedName = $Found.properties.distinguishedname[0]
        UserPrincipalName = $Found.properties.userprincipalname[0]
        ObjectGUID = New-Object GUID(,$Found.properties.objectguid[0])
        ObjectSID = (New-Object System.Security.Principal.SecurityIdentifier($Found.properties.objectsid[0],0)).Value
        MemberOf = $Found.properties.memberof
        Manager = $Found.properties.manager[0]
        LastLogon = ""
        LockedOut = ($Found.properties.lockouttime[0] -gt 0)
        BadPasswordCount = $Found.properties.badpwdcount[0]
        PasswordExpired = [bool]($Found.userAccountControl -band $PASSWORD_EXPIRED)
        PasswordLastSet = [DateTime]::FromFileTime($Found.properties.pwdlastset[0])
    }

    #Add Enable property, and dynamically retrieve other information
    $SAUser | Add-Member -MemberType ScriptProperty -Force -Name Enabled -Value { 
        $ACCOUNTDISABLE            = 0x000002
        $DONT_EXPIRE_PASSWORD      = 0x010000
        $PASSWORD_EXPIRED          = 0x800000
        $ACCOUNT_LOCKOUT           = 16
        $ADS_UF_PASSWD_NOTREQD     = 0x0020

        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($this.SamAccountName)))"
        $Found = $Searcher.FindOne()

        -not [bool]($Found.userAccountControl -band $ACCOUNTDISABLE)

        $this.LockedOut = ($Found.properties.lockouttime[0] -gt 0)
        $this.BadPasswordCount = $Found.properties.badpwdcount[0]
        $this.PasswordExpired = [bool]($Found.userAccountControl -band $PASSWORD_EXPIRED)
        $this.PasswordLastSet = [DateTime]::FromFileTime($Found.properties.pwdlastset[0])
        $this.MemberOf = $Found.properties.memberof
    }

    #Set Default View values
    $SAUser | Add-Member -Force -MemberType MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]@("Name","SamAccountName","Title","Enabled","LockedOut","BadPasswordCount","LastLogon"))))
    
    #Add user Unlock method
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name Unlock -Value { 
        $Found = [ADSI]"LDAP://$($this.DistinguishedName)"
        $Found.Put("lockouttime",0)
        $Found.SetInfo()
    }

    #GetGroups method, allows you to see just group name, includes a filter overload
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name GetGroups -Value { 
        Param (
            [string]$Filter = ".*"
        )

        $Groups = ForEach ($Group in $this.MemberOf)
        {
            If ($Group -match "cn=(?<GroupName>.*?)(?<!\\),")
            {
                $GroupName = $Matches.GroupName
                If ($GroupName -match $Filter)
                {
                    $GroupName
                }
            }
        }
        $Groups | Sort
    }

    #Remove Group method, includes a filter and support for multiple groups
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name RemoveGroup -Value {
        Param (
            [Parameter(Mandatory)]
            [string]$Name
        )

        $Groups = ForEach ($Group in $this.MemberOf)
        {
            If ($Group -match "cn=(?<GroupName>.*?)(?<!\\),")
            {
                $GroupName = $Matches.GroupName
                If ($GroupName -match $Name)
                {
                    [PSCustomObject]@{
                        Name = $GroupName
                        DistinguishedName = $Group
                    }
                }
            }
        }
        If (@($Groups).Count -gt 1)
        {
            $Remove = $Groups | Out-GridView -Title "Which groups do you want to remove from $($this.Name)?" -OutputMode Multiple
        }
        ElseIf (@($Groups).Count -eq 1) 
        {
            $Remove = $Groups
        }
        Else
        {
            Write-Verbose "No groups matched $Name"
            Return
        }

        ForEach ($Group in $Remove)
        {
            $GroupObj = [ADSI]"LDAP://$($Group.DistinguishedName)"
            $GroupObj.Remove("LDAP://$($this.DistinguishedName)")
        }
    }

    #Add Group method
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name AddGroup -Value {
        Param (
            [Parameter(Mandatory)]
            [string]$Name
        )

        Add-ADGroupMember -Identity $Name -Members $this.SamAccountName
    }
    <#
    


    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name GetLastLogon -Value {
        $DCs = Get-ADDomainController -Filter * | Select -ExpandProperty Name
        $Count = 1
        $DCData = ForEach ($DC in ($DCs))
        {
            Write-Progress -Activity "Retrieving user data from Domain Controllers" -Status "...$DC ($Count of $($DCs.Count))" -Id 0 -PercentComplete ($Count * 100 / $DCs.Count)
            Get-ADUser $this.SamAccountName -Server $DC -Properties lastLogon | Select @{Name="Last Logon";Expression={ If ($_.lastLogon) {[datetime]::FromFileTime($_.LastLogon)} }}
            $Count ++
        }
        Write-Progress -Activity " " -Status " " -Completed
        $this.LastLogon = $DCData | Sort "Last Logon" -Descending | Select -First 1 | Select -ExpandProperty "Last Logon"
        $this
    }


    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name ResetPassword -Value {
        Set-ADAccountPassword -Identity $this.SamAccountName -Reset
    }
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name FindLockout -Value {
        Find-LockOut $this.SamAccountName
    }
    #>
    $SAUser
}



Get-SAUser -User mpugh #| fl *
