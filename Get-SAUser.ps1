Function Get-SAUser {
    <#
    .SYNOPSIS
        athena health specific replacement for Get-ADUser
    .DESCRIPTION
        This is a more advanced version of Get-ADUser.  It allows you to see administrator specific fields in the default view, but
        also saves the user object in a global variable:

        $AHUser

        The advantage of this is if you want to do something to the object it's now persistent in your session.  Available methods are:

        AddGroup
            Usage: $AHUser.AddGroup("NameOfGroup")
        FindLockout
            Usage: $AHUser.FindLockedout()
        GetGroups
            Usage: $AHUser.GetGroups()
        GetLastLogon
            Usage: $AHUser.GetLastLogon()
        RemoveGroup
            Usage: $AHUser.RemoveGroup("NameOfGroup")
        ResetPassword
            Usage: $AHUser.ResetPassword()
                   Method will then prompt for new password
        Unlock
            Usage: $AHUser.Unlock()


        *** Requires AH.Automation Module ***

    .PARAMETER User
        Full username, or partial name of the user.  If partial all users that match will be shown in a window and you can select the
        one you want
    .INPUTS
        None
    .OUTPUTS
        $AHUser PSCustomObject
    .EXAMPLE
        Get-AHUser mpugh
        $AHUser.Unlock()

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

    $PropertyList = @(
        "Name"
        "SamAccountName"
        "Title"
        "Description"
        "GivenName"
        "Surname"
        "Manager"
        "PasswordNeverExpires"
        "PasswordNotRequired"
        "distinguishedName"
        "UserPrincipalName"
        "ObjectClass"
        "ObjectGUID"
        "SID"
    )

    $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$User))"
    $AH = $Searcher.FindOne()
    If ($AH.Count -eq 0)
    {
        Write-Verbose "No user matching $User, trying for a match"
        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(displayName=*$User*))"
        $AH = $Searcher.FindAll()
        If ($AH.Count -gt 1)
        {
            #Found more than one, need to select which one you want
            $Selected = $AH | Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},@{Name="DisplayName";Expression={ $_.properties.displayname }} | Out-GridView -Title "Select the user you want" -PassThru
            If (@($Selected).Count -eq 0)
            {
                Write-Error "No user found, exiting" -ErrorAction Stop
            }
            $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($Selected.SamAccountName)))"
            $AH = $Searcher.FindOne()
        }
        If ($AH.Count -eq 0)
        {
            Write-Error "No user found, exiting" -ErrorAction Stop
        }
    }

    $ACCOUNTDISABLE            = 0x000002
    $DONT_EXPIRE_PASSWORD      = 0x010000
    $PASSWORD_EXPIRED          = 0x800000
    $ACCOUNT_LOCKOUT           = 16
    $ADS_UF_PASSWD_NOTREQD     = 0x0020

    $Global:AHUser = [PSCustomObject]@{
        Name = $AH.properties.displayname[0]
        SamAccountName = $AH.properties.samaccountname[0]
        #Enabled = -not [bool]($AH.userAccountControl -band $ACCOUNTDISABLE)
        #LockedOut = ($AH.properties.lockouttime[0] -gt 0)
        Title = $AH.properties.title[0]
        Description = $AH.properties.description[0]
        GivenName = $AH.properties.givenname[0]
        Surname = $AH.properties.sn[0]
        PasswordNeverExpires = [bool]($AH.userAccountControl -band $DONT_EXPIRE_PASSWORD)
        PasswordNotRequired = [bool]($AH.userAccountControl -band $ADS_UF_PASSWD_NOTREQD)
        DistinguishedName = $AH.properties.distinguishedname[0]
        UserPrincipalName = $AH.properties.userprincipalname[0]
        ObjectGUID = New-Object GUID(,$AH.properties.objectguid[0])
        ObjectSID = (New-Object System.Security.Principal.SecurityIdentifier($AH.properties.objectsid[0],0)).Value
        #MemberOf = "" #$AH.properties.memberof
        Manager = $AH.properties.manager[0]
        LastLogon = ""
        #LockedOut = ($AH.properties.lockouttime[0] -gt 0)
        #BadPasswordCount = $AH.properties.badpwdcount[0]
        #PasswordExpired = [bool]($AH.userAccountControl -band $PASSWORD_EXPIRED)
        #PasswordLastSet = [DateTime]::FromFileTime($AH.properties.pwdlastset[0])
    }

    $PropertySet = "LockedOut","BadPasswordCount","PasswordExpired","PasswordLastSet","MemberOf"
    $Properties = $AHUser | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name
    ForEach ($Property in $PropertySet)
    {
        If ($Properties -notcontains $Property)
        {
            $AHUser | Add-Member -Force -MemberType NoteProperty -Name $Property -Value ""
        }
    }

    $AHUser | Add-Member -MemberType ScriptProperty -Force -Name Enabled -Value { 
        $ACCOUNTDISABLE            = 0x000002
        $DONT_EXPIRE_PASSWORD      = 0x010000
        $PASSWORD_EXPIRED          = 0x800000
        $ACCOUNT_LOCKOUT           = 16
        $ADS_UF_PASSWD_NOTREQD     = 0x0020

        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($this.SamAccountName)))"
        $AH = $Searcher.FindOne()

        -not [bool]($AH.userAccountControl -band $ACCOUNTDISABLE)

        $this.LockedOut = ($AH.properties.lockouttime[0] -gt 0)
        $this.BadPasswordCount = $AH.properties.badpwdcount[0]
        $this.PasswordExpired = [bool]($AH.userAccountControl -band $PASSWORD_EXPIRED)
        $this.PasswordLastSet = [DateTime]::FromFileTime($AH.properties.pwdlastset[0])
    }
    $AHUser | Add-Member -Force -MemberType MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]@("Name","SamAccountName","Title","Enabled","LockedOut","BadPasswordCount","LastLogon"))))
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name Unlock -Value { 
        Unlock-ADAccount -Identity $this.SamAccountName 
    }
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name GetGroups -Value { 
        Param (
            [string]$Filter = ".*"
        )

        Write-Verbose "Group Memberships for: $($this.Name)" -Verbose
        $Groups = ForEach ($Group in $this.MemberOf)
        {
            Get-ADGroup $Group | Select -ExpandProperty Name
        }
        $Groups | Select-String $Filter | Sort
    }
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name GetLastLogon -Value {
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
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name AddGroup -Value {
        Param (
            [Parameter(Mandatory)]
            [string]$Name
        )

        Add-ADGroupMember -Identity $Name -Members $this.SamAccountName
    }
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name RemoveGroup -Value {
        Param (
            [Parameter(Mandatory)]
            [string]$Name
        )

        Remove-ADGroupMember -Identity $Name -Members $this.SamAccountName -Confirm:$false
    }
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name ResetPassword -Value {
        Set-ADAccountPassword -Identity $this.SamAccountName -Reset
    }
    $AHUser | Add-Member -Force -MemberType ScriptMethod -Name FindLockout -Value {
        Find-LockOut $this.SamAccountName
    }

    $AHUser
#>
}



Get-SAUser -User mpugh | fl *
