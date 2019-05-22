# Get-SAUser
The idea behind Get-SAUser was to provide a single function to do your most common administrative tasks.  When managing users on a day to day basis what do we do?  Reset passwords, unlock accounts, add and remove from groups and do some forensics about why they locked out in the first place.  All of this can be done from Get-SAUser.

[Blog post about Get-SAUser.](https://thesurlyadmin.com/2016/08/11/simple-day-to-day-administration/)

# $SAUser
Get-SAUser creates a global variable called $SAUser, and this is where all the magic happens.  After running Get-SAUser, it will display some basic details about the user (and a better default set then what Get-ADUser gives you) and populate the $SAUser variable.  From $SAUser you can run several methods:

## Methods
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
			   
It's also important to remember that $SAUser is dynamically updated every time you display the variable.  The following fields will update every time:

             Enabled
             LockedOut
             BadPasswordCount
             PasswordExpired
             PasswordLastSet
             MemberOf
			 
