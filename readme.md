![BuildStatus](https://ci.appveyor.com/api/projects/status/e5wk05bj6yy3pymf?svg=true) [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/SimpleADAdmin.svg?style=plastic)](https://www.powershellgallery.com/packages/SimpleADAdmin)

# SimpleADAdmin
The idea behind SimpleADAdmin was to provide a single function to do your most common administrative tasks.  When managing users on a day to day basis what do we do?  Reset passwords, unlock accounts, add and remove from groups and do some forensics about why they locked out in the first place.  All of this can be done from Get-SAUser.  A new addition is Get-SAGroup which allows you to do similar things with Active Directory groups (see below).

[Blog post about Get-SAUser.](https://thesurlyadmin.com/2016/08/11/simple-day-to-day-administration/)

![Populate $SAUser](/media/Get-SAUser1.png)

## $SAUser
Get-SAUser creates a global variable called $SAUser, and this is where all the magic happens.  After running Get-SAUser, it will display some basic details about the user (and a better default set then what Get-ADUser gives you) and populate the $SAUser variable.  There is a lot more data in $SAUser then the default view, but I wanted to keep it simple.  You use methods assigned to $SAUser to make changes (see below).

![All $SAUser properties](/media/Get-SAUser2.png)

### Methods
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

![Example of using a method](/media/Get-SAUser3.png)


## Get-SAGroup
Get-SAGroup works just like Get-SAUser, only focused on groups.  A global variable call $SAGroup is created, which also features a number of methods for working with the group.

### Methods
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
			   
			   
## Dynamic Updates
One of the unique capabilities of both $SAUser and $SAGroup is the fact that all the properties in them will dynamically update every time you display the variable.  You'll be able to monitor your changes in real time.
			 
