Class SAUser
{
    [string]   $Name
    [string]   $SamAccountName
    [string]   $Title
    [string]   $Description
    [string]   $GivenName
    [string]   $Surname
    [string]   $Email
    [boolean]  $PasswordNeverExpires
    [boolean]  $PasswordNotRequired
    [string]   $DistinguishedName
    [string]   $UserPrincipalName
    [guid]     $ObjectGUID
    [string]   $ObjectSID
    [string[]] $MemberOf
    [string]   $Manager
    [string]   $LastLogon
    [boolean]  $LockedOut
    [int]      $BadPasswordCount
    [boolean]  $PasswordExpired
    [datetime] $PasswordLastSet

    SAUser ()
    {
        Write-Error "You must provide a username" -ErrorAction Stop
    }

    SAUser ( [string]$Identity )
    {
        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$Identity))"
        $Found = $Searcher.FindOne()

        If ($null -eq $Found.properties.samaccountname)
        {
            Write-Error "Unable to locate user name ""$Identity""" -ErrorAction Stop
        }

        # Fill in the object
        $this.SamAccountName = $Found.properties.samaccountname
        $this.EnumerateFields()

        # Add Enabled field, and field refresh
        $this | Add-Member -MemberType ScriptProperty -Name Enabled -Value {
            $ACCOUNTDISABLE            = 0x000002

            $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($this.SamAccountName)))"
            $Found = $Searcher.FindOne()

            Write-Output (-not [bool]($Found.userAccountControl -band $ACCOUNTDISABLE))
            $this.EnumerateFields()
        }

        # Set Default property view
        $DefaultDisplayProperties = @(
            "Name"
            "SamAccountName"
            "Title"
            "Enabled"
            "LockedOut"
            "BadPasswordCount"
            "LastLogon"
        )
        $this | Add-Member -Force -MemberType MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]$DefaultDisplayProperties)))
    }

    hidden [void] EnumerateFields ()
    {
        $ACCOUNTDISABLE            = 0x000002
        $DONT_EXPIRE_PASSWORD      = 0x010000
        $PASSWORD_EXPIRED          = 0x800000
        $ADS_UF_PASSWD_NOTREQD     = 0x0020

        $Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(samAccountName=$($this.SamAccountName)))"
        $Found = $Searcher.FindOne()

        $this.Name                 = $Found.properties.displayname | Select-Object -First 1
        $this.SamAccountName       = $Found.properties.samaccountname | Select-Object -First 1
        $this.Title                = $Found.properties.title | Select-Object -First 1
        $this.Description          = $Found.properties.description | Select-Object -First 1
        $this.GivenName            = $Found.properties.givenname | Select-Object -First 1
        $this.Surname              = $Found.properties.sn | Select-Object -First 1
        $this.Email                = $Found.properties.mail | Select-Object -First 1
        $this.PasswordNeverExpires = [bool]($Found.userAccountControl -band $DONT_EXPIRE_PASSWORD)
        $this.PasswordNotRequired  = [bool]($Found.userAccountControl -band $ADS_UF_PASSWD_NOTREQD)
        $this.DistinguishedName    = $Found.properties.distinguishedname | Select-Object -First 1
        $this.UserPrincipalName    = $Found.properties.userprincipalname | Select-Object -First 1
        $this.ObjectGUID           = New-Object GUID(,($Found.properties.objectguid | Select-Object -First 1))
        $this.ObjectSID            = (New-Object System.Security.Principal.SecurityIdentifier(($Found.properties.objectsid | Select-Object -First 1),0)).Value
        $this.MemberOf             = $Found.properties.memberof
        $this.Manager              = $Found.properties.manager | Select-Object -First 1
        $this.LastLogon            = "Unknown"
        $this.LockedOut            = (($Found.properties.lockouttime | Select-Object -First 1) -gt 0)
        $this.BadPasswordCount     = $Found.properties.badpwdcount | Select-Object -First 1
        $this.PasswordExpired      = [bool]($Found.userAccountControl -band $PASSWORD_EXPIRED)
        $this.PasswordLastSet      = [DateTime]::FromFileTime(($Found.properties.pwdlastset | Select-Object -First 1))
    }

    hidden [PSCustomObject] GetGroupNames ()
    {
        $Results = ForEach ($Member in $this.MemberOf)
        {
            $Searcher = [ADSISearcher]"(distinguishedName=$Member)"
            $Found = $Searcher.FindOne()
            [PSCustomObject]@{
                Name              = $Found.properties.name | Select -First 1
                SamAccountName    = $Found.properties.samaccountname | Select -First 1
                distinguishedName = $Found.properties.distinguishedname | Select -First 1
            }
        }
        Return $Results
    }

    hidden [void] AddUserToGroup ( [string]$DN )
    {
        $Searcher = [ADSISearcher]"(distinguishedName=$DN)"
        $Found = $Searcher.FindOne()

        If ($this.MemberOf -contains $DN)
        {
            Write-Error "User is already a member of group ""$($Found.properties.name)""" -ErrorAction Stop
        }
        Else
        {
            $GroupObj = [ADSI]"LDAP://$($Found.properties.distinguishedname)"
            $GroupObj.Add("LDAP://$($this.distinguishedName)")
            Write-Verbose "Added to Group ""$($Found.properties.name)"", will take a minute to show up in `$SAUser" -Verbose
        }
    }

    [void] Unlock ()
    {
        $Found = [ADSI]"LDAP://$($this.DistinguishedName)"
        $Found.Put("lockouttime",0)
        $Found.SetInfo()
    }

    [PSCustomObject[]] GetGroups ()
    {
        $Groups = $this.GetGroupNames() | Sort
        Return $Groups
    }

    [PSCustomObject[]] GetGroups ( [string]$Filter )
    {
        $Groups = $this.GetGroupNames() | Where Name -match $Filter | Sort
        Return $Groups
    }

    [void] RemoveGroup ( [string]$GroupName )
    {
        $Searcher = [ADSISearcher]"(&(objectCategory=group)(samAccountName=$GroupName))"
        $Found = $Searcher.FindOne()

        If ($null -eq $Found.properties.samaccountname)
        {
            Write-Error "Unable to locate group ""$GroupName""" -ErrorAction Stop
        }
        Else
        {
            If ($this.MemberOf -contains $Found.properties.distinguishedname)
            {
                $GroupObj = [ADSI]"LDAP://$($Found.properties.distinguishedname)"
                $GroupObj.Remove("LDAP://$($this.DistinguishedName)")
                Write-Verbose "Removed from group ""$($Found.properties.name)""" -Verbose
            }
            Else
            {
                Write-Error "User is not currently a member of ""$GroupName""" -ErrorAction Stop
            }
        }
    }

    [void] AddGroup ( [string]$GroupName )
    {
        $Searcher = [ADSISearcher]"(&(objectCategory=group)(objectClass=group)(samAccountName=*$GroupName*))"
        $Searcher.PageSize = 1000
        $Found = $Searcher.FindAll()

        If (@($Found).Count -gt 1)
        {
            $Selected = $Found | 
                Select-Object @{Name="SamAccountName";Expression={ $_.properties.samaccountname }},
                    @{Name="DisplayName";Expression={ $_.properties.displayname }},
                    @{Name="DistinguishedName";Expression={ $_.properties.distinguishedname }} | 
                Out-GridView -Title "Select the groups to add" -OutputMode Multiple
            If (@($Selected).Count -ge 1)
            {
                $Found = ForEach ($Group in $Selected)
                {
                    $this.AddUserToGroup($Group.DistinguishedName)
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
            Write-Warning "No group matching ""*$GroupName*"" found"
            Return
        }
        Else
        {
            $this.AddUserToGroup($Found.properties.distinguishedname)
        }
    }

    [void] ResetPassword ()
    {
    }

    [void] GetLastLogon ()
    {
    }

    [void] FindLockout ()
    {
    }


}