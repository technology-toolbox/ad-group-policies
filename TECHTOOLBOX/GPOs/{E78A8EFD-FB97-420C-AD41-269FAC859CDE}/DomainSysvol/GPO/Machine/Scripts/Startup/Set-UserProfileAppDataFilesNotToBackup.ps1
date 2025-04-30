$userProfileAppDataFilesNotToBackup = @("%UserProfile%\AppData\* /s")

# Note: "%UserProfile%\AppData\*" only works for the currently logged in
# user. To exclude the AppData files for *all* users, enumerate each user
# profile folder and add the AppData folder for each one in the list of
# files not to backup.
Get-WmiObject -ClassName Win32_UserProfile |
    # exclude "special" user profiles (e.g. LocalService and NetworkService)
    Where-Object { $_.Special -eq $false } |
    # exclude NT_SERVICE user profiles (e.g. MSSQLSERVER)
    Where-Object { $_.SID -notlike "S-1-5-80-*" } |
    # exclude IIS user profiles (e.g. DefaultAppPool)
    Where-Object { $_.SID -notlike "S-1-5-82-*" } |
    # sort the items (to make it easier to inspect the registry value)
    Sort-Object LocalPath |
    # add the AppData files for each user profile to the list
    ForEach-Object {
        $userProfileAppDataFilesNotToBackup += `
             ($_.LocalPath + "\AppData\* /s")
    }

Set-ItemProperty `
    -Path ("HKLM:\SYSTEM\CurrentControlSet\Control\BackupRestore" `
        + "\FilesNotToBackup") `
    -Name "User Profile AppData" `
    -Value $userProfileAppDataFilesNotToBackup `
    -Type MultiString