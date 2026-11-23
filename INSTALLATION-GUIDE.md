# Installation guide

1. Run the sample in [Start here](START-HERE.md). Choose a Windows file server and an NTFS volume. Create separate folders for the inbox and the master, such as `D:\Inventory\Inbox` and `D:\Inventory\Master`.
2. Share the inbox, for example as `\\fileserver.contoso.com\ComputerInventory$`. Replace the placeholder server and share with your own values. Create one uppercase-named folder per managed computer. Provision and test SMB and NTFS permissions using [Security](SECURITY.md). Keep clients out of the master folder.
3. Create a client configuration and a server configuration as described in [Configuration](CONFIGURATION-GUIDE.md). On clients, set InboxRoot to your share and set staging and log paths to approved local directories writable by the account that runs collection. On the merge server, use the local inbox path and an outside-inbox local master path. Create the master parent directory in advance and give the merge identity Modify access.
4. Pilot client collection under the actual execution identity. Choose startup for device-only data, or use logon where the account has local CIM and isolated write permissions. Follow [Group Policy deployment](GROUP-POLICY-DEPLOYMENT.md) for the editor path and rollout.
5. In Task Scheduler on the file server, create a task under a dedicated least-privilege account with **Run whether user is logged on or not**. Add a trigger such as hourly. Set **If the task is already running** to **Do not start a new instance**. Use the executable below and replace the paths. Store the binaries and task configuration under an administrator-maintained directory.
   
   Program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
   
   Arguments: `-NoProfile -NonInteractive -File "C:\InventoryToolkit\Merge-InventoryCSV.ps1" -ConfigPath "C:\InventoryToolkit\server.config.json"`
6. Run the task once. Confirm a successful task result and verify a new submission appears in the correct PC folder. Open the master with **Data > From Text/CSV** in Excel, specifying UTF-8 and comma. Collect on the same computer again and verify the master still has one row for that device.
7. Establish inbox and local log retention. The scripts never delete completed submissions. Schedule server-side housekeeping under the merge identity outside merge windows. Keep the latest valid record for each active device and back up the master. Pilot with two distinct principals and test both allowed and denied operations.
