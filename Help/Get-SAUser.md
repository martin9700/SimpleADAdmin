---
external help file: SimpleADAdmin-help.xml
Module Name: SimpleADAdmin
online version: https://github.com/martin9700/SimpleADAdmin
schema: 2.0.0
---

# Get-SAUser

## SYNOPSIS
Simple function that will allow you to do the most common user administrative tasks from a single place.

## SYNTAX

```
Get-SAUser [-Identity] <String> [<CommonParameters>]
```

## DESCRIPTION
This is a more advanced version of Get-ADUser. 
It allows you to see administratively useful fields in the default view, but
also saves the user object in a global variable:

$SAUser

The advantage of this is if you want to do something to the object it's now persistent in your session. 
All properties on
$SAUser are dynamic, meaning they will update from Active Directory every time you display the variable.

This means you don't have to keep rerunning Get-SAUser after you've made a change in order to see it.

Thee are several methods available on $SAUser for an administrator to use, they are:

AddGroup
          Usage: $SAUser.AddGroup("NameOfGroup")
    Description: Add the user to a group.
       Overload: You can add the name of a group in the overload and the function will find all groups that match that name
                 pattern and let you select which group or groups you want to add. 
If you give an exact match it will just
                 add it without prompting.

FindLockout
          Usage: $SAUser.FindLockedout()
    Description: Will go to the PDC emulator and look for event ID 4740 (lockout) in the Security Event Log. 
       Overload: None

GetGroups
          Usage: $SAUser.GetGroups()
    Description: The "MemberOf" field will always show what groups the user is in, but it's the FQDN. 
Use the GetGroups() 
                 method to see just their Name.
       Overload: You can add an overload to filter the result:  $SAUser.GetGroups("test")

GetLastLogon
          Usage: $SAUser.GetLastLogon()
    Description: Will go out to all domain controllers in your domain and locate the latest logon for the user.
       Overload: None

RemoveGroup
          Usage: $SAUser.RemoveGroup("NameOfGroup")
    Description: Remove the user from the specified group. 
       Overload: Name of the group, or closest match. 
If you specify the exact name, or the filter data you provide only has one
                 match thenthe user will be removed from the group without prompt. 
If there are more then one match you will be
                 asked to select the group or groups you want to remove.

ResetPassword
          Usage: $SAUser.ResetPassword()
    Description: Method will then prompt for new password
       Overload: None

Unlock
          Usage: $SAUser.Unlock()
    Description: Will unlock the user account
       Overload: None

## EXAMPLES

### EXAMPLE 1
```
Get-SAUser mpugh
```

$SAUser.Unlock()

Get user information for mpugh, see that the account is locked. 
Use the Unlock() method to unlock the account.

### EXAMPLE 2
```
Get-SAUser Martin
```

Shows a large list of users. 
Select Martin Pugh

## PARAMETERS

### -Identity
{{ Fill Identity Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases: User, UserName, SamAccountName, Name

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
## OUTPUTS

### $SAUser PSCustomObject
## NOTES
Author:             Martin Pugh
Date:               8/11/2016

Changelog:
    08/11/16        MLP - MVP (minimum viable product) release with Readme.md and updated help   
    05/26/19        MLP - Converted to using class

## RELATED LINKS

[https://github.com/martin9700/SimpleADAdmin](https://github.com/martin9700/SimpleADAdmin)

