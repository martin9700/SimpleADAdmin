Function Get-SAUser {
    <#
    .SYNOPSIS
        Simple function that will allow you to do the most common user administrative tasks from a single place.
    .DESCRIPTION
        This is a more advanced version of Get-ADUser.  It allows you to see administratively useful fields in the default view, but
        also saves the user object in a global variable:

        $SAUser

        The advantage of this is if you want to do something to the object it's now persistent in your session.  Six properties on
        $SAUser are dynamic, meaning they will update from Active Directory every time you display the variable:
             Enabled
             LockedOut
             BadPasswordCount
             PasswordExpired
             PasswordLastSet
             MemberOf
        This means you don't have to keep rerunning Get-SAUser after you've made a change in order to see it.
        
        Thee are several methods available on $SAUser for an administrator to use, they are:

        AddGroup
                  Usage: $SAUser.AddGroup("NameOfGroup")
            Description: Add the user to a group.
               Overload: You can add the name of a group in the overload and the function will find all groups that match that name
                         pattern and let you select which group or groups you want to add.  If you give an exact match it will just
                         add it without prompting.

        FindLockout
                  Usage: $SAUser.FindLockedout()
            Description: Will go to the PDC emulator and look for event ID 4740 (lockout) in the Security Event Log. 
               Overload: None

        GetGroups
                  Usage: $SAUser.GetGroups()
            Description: The "MemberOf" field will always show what groups the user is in, but it's the FQDN.  Use the GetGroups() 
                         method to see just their Name.
               Overload: You can add an overload to filter the result:  $SAUser.GetGroups("test")

        GetLastLogon
                  Usage: $SAUser.GetLastLogon()
            Description: Will go out to all domain controllers in your domain and locate the latest logon for the user.
               Overload: None

        RemoveGroup
                  Usage: $SAUser.RemoveGroup("NameOfGroup")
            Description: Remove the user from the specified group. 
               Overload: Name of the group, or closest match.  If you specify the exact name, or the filter data you provide only has one
                         match thenthe user will be removed from the group without prompt.  If there are more then one match you will be
                         asked to select the group or groups you want to remove.

        ResetPassword
                  Usage: $SAUser.ResetPassword()
            Description: Method will then prompt for new password
               Overload: None

        Unlock
                  Usage: $SAUser.Unlock()
            Description: Will unlock the user account
               Overload: None

    .PARAMETER User
        Full SamAccountName, or partial name of the user.  If partial all users that match will be shown in a window and you can select the
        one you want

    .PARAMETER DefaultDisplayProperties
        This is the default properties that will display when you type $SAUser.  All properties can be displayed by using Format-List:  $SAUser | Format-List *

    .INPUTS
        None
    .OUTPUTS
        $SAUser PSCustomObject
    .EXAMPLE
        Get-SAUser mpugh
        $SAUser.Unlock()

        Get user information for mpugh, see that the account is locked.  Use the Unlock() method to unlock the account.

    .EXAMPLE
        Get-SAUser Martin

        Shows a large list of users.  Select Martin Pugh
    .NOTES
        Author:             Martin Pugh
        Date:               8/11/2016
      
        Changelog:
            08/11/16        MLP - MVP (minimum viable product) release with Readme.md and updated help   
    .LINK
        https://github.com/martin9700/Get-SAUser
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [Alias("User","UserName","SamAccountName","Name")]
        [string]$Identity,
        [string[]]$DefaultDisplayProperties = @("Name","SamAccountName","Title","Enabled","LockedOut","BadPasswordCount","LastLogon")
    )

    $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$Identity))"
    $Found = $Searcher.FindOne()
    If ($Found.Count -eq 0)
    {
        Write-Verbose "No user matching $SAUser, trying for a match"
        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(displayName=*$Identity*))"
        $Found = $Searcher.FindAll()
        If ($Found.Count -gt 1)
        {
            #Found more than one, need to select which one you want
            $Selected = $Found | Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},@{Name="DisplayName";Expression={ $_.properties.displayname }} | Out-GridView -Title "Select the user you want" -PassThru
            If (@($Selected).Count -eq 0)
            {
                Write-Warning "No user selected"
                Return
            }
            $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($Selected.SamAccountName)))"
            $Found = $Searcher.FindOne()
        }
        If ($Found.Count -eq 0)
        {
            Write-Error "No user found, exiting" -ErrorAction Stop
        }
    }

    $DONT_EXPIRE_PASSWORD      = 0x010000
    $PASSWORD_EXPIRED          = 0x800000
    $ADS_UF_PASSWD_NOTREQD     = 0x0020

    $Global:SAUser = [PSCustomObject]@{
        Name                 = $Found.properties.displayname[0]
        SamAccountName       = $Found.properties.samaccountname[0]
        Title                = $Found.properties.title[0]
        Description          = $Found.properties.description[0]
        GivenName            = $Found.properties.givenname[0]
        Surname              = $Found.properties.sn[0]
        Email                = $Found.properties.mail[0]
        PasswordNeverExpires = [bool]($Found.userAccountControl -band $DONT_EXPIRE_PASSWORD)
        PasswordNotRequired  = [bool]($Found.userAccountControl -band $ADS_UF_PASSWD_NOTREQD)
        DistinguishedName    = $Found.properties.distinguishedname[0]
        UserPrincipalName    = $Found.properties.userprincipalname[0]
        ObjectGUID           = New-Object GUID(,$Found.properties.objectguid[0])
        ObjectSID            = (New-Object System.Security.Principal.SecurityIdentifier($Found.properties.objectsid[0],0)).Value
        MemberOf             = $Found.properties.memberof
        Manager              = $Found.properties.manager[0]
        LastLogon            = "Unknown"
        LockedOut            = ($Found.properties.lockouttime[0] -gt 0)
        BadPasswordCount     = $Found.properties.badpwdcount[0]
        PasswordExpired      = [bool]($Found.userAccountControl -band $PASSWORD_EXPIRED)
        PasswordLastSet      = [DateTime]::FromFileTime($Found.properties.pwdlastset[0])
    }

    #Add Enable property, and dynamically retrieve other information
    $SAUser | Add-Member -MemberType ScriptProperty -Force -Name Enabled -Value { 
        $ACCOUNTDISABLE            = 0x000002
        $PASSWORD_EXPIRED          = 0x800000

        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($this.SamAccountName)))"
        $Found = $Searcher.FindOne()

        -not [bool]($Found.userAccountControl -band $ACCOUNTDISABLE)

        $this.LockedOut        = ($Found.properties.lockouttime[0] -gt 0)
        $this.BadPasswordCount = $Found.properties.badpwdcount[0]
        $this.PasswordExpired  = [bool]($Found.userAccountControl -band $PASSWORD_EXPIRED)
        $this.PasswordLastSet  = [DateTime]::FromFileTime($Found.properties.pwdlastset[0])
        $this.MemberOf         = $Found.properties.memberof
    }

    #Set Default View values
    $SAUser | Add-Member -Force -MemberType MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]$DefaultDisplayProperties)))
    
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

        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($this.SamAccountName)))"
        $Found = $Searcher.FindOne()

        $Groups = ForEach ($Group in $Found.properties.memberof)
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
            If (@($Remove).Count -eq 0)
            {
                Write-Warning "No groups selected"
                Return
            }
        }
        ElseIf (@($Groups).Count -eq 1) 
        {
            $Remove = @($Groups)
        }
        Else
        {
            Write-Warning "No groups matched $Name"
            Return
        }

        ForEach ($Group in $Remove)
        {
            $GroupObj = [ADSI]"LDAP://$($Group.DistinguishedName)"
            $GroupObj.Remove("LDAP://$($this.DistinguishedName)")
            Write-Verbose "Removed from group $($Group.Name)" -Verbose
        }
    }

    #Add Group method
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name AddGroup -Value {
        Param (
            [Parameter(Mandatory)]
            [string]$Name
        )
        
        $Searcher = [ADSISearcher]"(&(objectCategory=group)(objectClass=group)(name=*$Name*))"
        $Searcher.PageSize = 1000
        $Found = $Searcher.FindAll()
        If (@($Found).Count -gt 1)
        {
            $Selected = $Found | Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},@{Name="DisplayName";Expression={ $_.properties.displayname }} | Out-GridView -Title "Select the groups to add" -OutputMode Multiple
            If (@($Selected).Count -ge 1)
            {
                $Found = ForEach ($Group in $Selected)
                {
                    $Searcher = [ADSISearcher]"(&(objectCategory=group)(objectClass=group)(samAccountName=$($Group.SamAccountName)))"
                    $Searcher.FindOne()
                }
            }
            Else
            {
                Write-Warning "No group selected"
                Return
            }
        }
        ElseIf (@($Found).Count -eq 0)
        {
            Write-Warning "No group matching *$Name* found"
            Return
        }
        ForEach ($Group in $Found)
        {
            $GroupObj = [ADSI]"LDAP://$($Group.properties.distinguishedname)"
            $GroupObj.Add("LDAP://$($this.distinguishedName)")
            Write-Verbose "Added to Group $($Group.properties.name), will take a minute to show up in `$SAUser" -Verbose
        }
    }

    #Reset Password
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name ResetPassword -Value {
        $Password1 = Get-Credential -UserName $this.SamAccountName -Message "Enter new password"
        $Password2 = Get-Credential -UserName $this.SamAccountName -Message "Verify new password"
        If ($Password1.GetNetworkCredential().Password -eq $Password2.GetNetworkCredential().Password)
        {
            $UserObj = [ADSI]"LDAP://$($this.distinguishedName)"
            $UserObj.SetPassword($Password1.GetNetworkCredential().Password)
        }
        Else
        {
            Write-Warning "Passwords did not match"
        }
    }

    #Populate LastLogon property
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name GetLastLogon -Value {
        $DCs = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers | Select -ExpandProperty Name
        $Count = 1
        $DCData = ForEach ($DC in ($DCs))
        {
            Write-Progress -Activity "Retrieving user data from Domain Controllers" -Status "...$DC ($Count of $($DCs.Count))" -Id 0 -PercentComplete ($Count * 100 / $DCs.Count)
            $UserObj = [ADSI]"LDAP://$DC/$($this.distinguishedName)"
            If ($UserObj.lastlogon[0] -ne $null)
            {
                [datetime]::FromFileTime($UserObj.ConvertLargeIntegerToInt64($UserObj.lastLogon[0]))
            }
            $Count ++
        }
        Write-Progress -Activity " " -Status " " -Completed
        $this.LastLogon = $DCData | Sort -Descending | Select -First 1
        $this
    }

    #Find out on what computer a user was last locked up at
    $SAUser | Add-Member -Force -MemberType ScriptMethod -Name FindLockout -Value {
        Param (
            [datetime]$Start = ((Get-Date).AddDays(-2)),
            [datetime]$End = (Get-Date)
        )

        Write-Verbose "Locating PDC Emulator..." -Verbose
        $PDCEmulator = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers | Where Roles -Contains "PdcRole" | Select -ExpandProperty Name
        Write-Verbose "PDC Emulator: $PDCEmulator" -Verbose

        $FilterHash = @{
            LogName = "Security"
            StartTime = $Start
            EndTime = $End
            ID = 4740
        }

        Write-Verbose "Searching (be patient)..." -Verbose
        Try {
            Get-WinEvent -ComputerName $PDCEmulator -FilterHashtable $FilterHash -ErrorAction Stop | Where Message -Like "*$($this.SamAccountName)*" | Select TimeCreated,@{Name="User";Expression={$Username}},@{Name="LockedOn";Expression={$PSItem.Properties.Value[1]}},@{Name="DC";Expression={$PDCEmulator}}
        }
        Catch {
            Write-Error "Unable to retrieve event log for $PDCEmulator because ""$_""" -ErrorAction Stop
        }
    }

    $SAUser
}



Get-SAUser -User mpugh #| fl *
