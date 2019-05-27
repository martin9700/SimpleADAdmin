---
external help file: SimpleADAdmin-help.xml
Module Name: SimpleADAdmin
online version:
schema: 2.0.0
---

# Get-SAGroup

## SYNOPSIS
Simple function that will allow you to do the most common group administrative tasks from a single place.

## SYNTAX

```
Get-SAGroup [-Identity] <String> [<CommonParameters>]
```

## DESCRIPTION
This is a more advanced version of Get-ADGroup. 
It allows you to see administratively useful fields in the default view, but
also saves the user object in a global variable:

$SAGroup

The advantage of this is if you want to do something to the object it's now persistent in your session. 
All properties on
$SAGroup are dynamic, meaning they will update from Active Directory every time you display the variable, which means you don't 
have to keep rerunning Get-SAGroup after you've made a change in order to see it.

Thee are several methods available on $SAUser for an administrator to use, they are:

GetMembers
          Usage: $SAUser.GetMembers()
    Description: Shows every user and group who is a member of the group.
       Overload: None

GetMembersRecursive
          Usage: $SAUser.GetMembersRecursive()
    Description: Shows every user who is a member of the group, even if they are part of a group that's assigned to this one. 
       Overload: None

AddMember
          Usage: $SAUser.AddMember(SamAccountName)
    Description: Add the designated user to the group
       Overload: SamAccountName for the user you want to add

RemoveMember
          Usage: $SAUser.RemoveMember(SamAccountName)
    Description: Remove the designated user to the group
       Overload: SamAccountName for the user you want to remove

## EXAMPLES

### EXAMPLE 1
```
Get-SAGroup "Test-Group"
```

Name              : Test Group
SamAccountName    : Test-Group
Description       : Distribution list for internal tests only
Info              : 
Email             : test-group@gmail.com
DistinguishedName : CN=test-group,OU=Internal,OU=Distribution Lists,DC=surlyadmin,DC=com
ObjectGUID        : d2fe1397-40bb-48c6-8bf7-5f5c80e127b1
ObjectSID         : S-1-5-21-1991516528-409794927-3010460085-114238
MemberOf          : 
Members           : {CN=surlyadmins,OU=Internal,OU=Distribution Lists,DC=surlyadmin,DC=com}
ManagedBy         : CN=Martin Pugh,OU=Employees,DC=surlyadmin,DC=com
GroupCategory     : Distribution
GroupScope        : Universal
WhenCreated       : 2/7/2018 1:46:52 PM
LastModified      : 9/6/2018 6:04:46 PM

## PARAMETERS

### -Identity
Name of the group you want to interact with. 
If the group cannot be found, it will attempt to look for groups with a like
name and give you the option of selecting one of those.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Group, SamAccountName, Name

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author:             Martin Pugh
Twitter:            @thesurlyadm1n
Spiceworks:         Martin9700
Blog:               www.thesurlyadmin.com

Changelog:
    05/25/19        Initial Release

## RELATED LINKS
