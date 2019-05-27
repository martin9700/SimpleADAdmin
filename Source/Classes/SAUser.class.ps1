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
    [string]   $LastLogon = "Unknown"
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
                Name              = $Found.properties.name | Select-Object -First 1
                SamAccountName    = $Found.properties.samaccountname | Select-Object -First 1
                distinguishedName = $Found.properties.distinguishedname | Select-Object -First 1
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

    hidden [PSCustomObject] Get4740Events ( [datetime]$Start, [datetime]$End )
    {
        $PDCEmulator = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers | Where-Object Roles -Contains "PdcRole" | Select-Object -ExpandProperty Name
        Write-Verbose "PDC Emulator: $PDCEmulator" -Verbose

        $FilterHash = @{
            LogName   = "Security"
            StartTime = $Start
            EndTime   = $End
            ID        = 4740
        }

        $Results = $null
        Write-Verbose "Searching (be patient)..." -Verbose
        Try {
            $Results = Get-WinEvent -ComputerName $PDCEmulator -FilterHashtable $FilterHash -ErrorAction Stop | 
                Where-Object Message -Like "*$($this.SamAccountName)*" | 
                Select-Object TimeCreated,
                    @{Name="User";Expression={$Username}},
                    @{Name="LockedOn";Expression={$PSItem.Properties.Value[1]}},
                    @{Name="DC";Expression={$PDCEmulator}}
        }
        Catch {
            Write-Error "Unable to retrieve event log for $PDCEmulator because ""$_""" -ErrorAction Stop
        }
        Return $Results
    }

    [void] Unlock ()
    {
        $Found = [ADSI]"LDAP://$($this.DistinguishedName)"
        $Found.Put("lockouttime",0)
        $Found.SetInfo()
    }

    [PSCustomObject[]] GetGroups ()
    {
        $Groups = $this.GetGroupNames() | Sort-Object
        Return $Groups
    }

    [PSCustomObject[]] GetGroups ( [string]$Filter )
    {
        $Groups = $this.GetGroupNames() | Where-Object Name -match $Filter | Sort-Object
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
        $Password1 = Get-Credential -UserName $this.SamAccountName -Message "Enter new password"
        $Password2 = Get-Credential -UserName $this.SamAccountName -Message "Verify new password"
        If ($Password1.GetNetworkCredential().Password -ceq $Password2.GetNetworkCredential().Password)
        {
            $UserObj = [ADSI]"LDAP://$($this.distinguishedName)"
            $UserObj.SetPassword($Password1.GetNetworkCredential().Password)
        }
        Else
        {
            Write-Error "Passwords did not match" -ErrorAction Stop
        }
    }

    [void] GetLastLogon ()
    {
        $DCs = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers | Select-Object -ExpandProperty Name
        $Count = 1
        $DCData = ForEach ($DC in $DCs)
        {
            Write-Progress -Activity "Retrieving user data from Domain Controllers" -Status "...$DC ($Count of $($DCs.Count))" -Id 0 -PercentComplete ($Count * 100 / $DCs.Count)
            $UserObj = [ADSI]"LDAP://$DC/$($this.distinguishedName)"
            If ($null -ne ($UserObj.lastlogon | Select-Object -First 1))
            {
                [datetime]::FromFileTime($UserObj.ConvertLargeIntegerToInt64(($UserObj.lastLogon | Select-Object -First 1)))
            }
            $Count ++
        }
        Write-Progress -Activity " " -Status " " -Completed
        $this.LastLogon = ($DCData | Sort-Object -Descending | Select-Object -First 1).ToString()
        
        Write-Verbose "Last Logon for $($this.Name) was $($this.LastLogon)" -Verbose
    }

    [PSCustomObject] FindLockout ()
    {
        $Start = (Get-Date).AddDays(-2)
        $End   = Get-Date
        $Results = $this.Get4740Events($Start, $End)
        Return $Results
    }

    [PSCustomObject] FindLockout ( [datetime]$Start )
    {
        $End   = Get-Date
        $Results = $this.Get4740Events($Start, $End)
        Return $Results
    }

    [PSCustomObject] FindLockout ( [datetime]$Start, [datetime]$End)
    {
        $Results = $this.Get4740Events($Start, $End)
        Return $Results
    }


}