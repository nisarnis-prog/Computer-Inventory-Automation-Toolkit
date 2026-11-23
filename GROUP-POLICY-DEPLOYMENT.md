# Group Policy deployment

## Device inventory at startup

1. On an admin workstation open Group Policy Management. Create and link a test GPO to an OU containing pilot computers. Scope it to those computers.
2. Edit **Computer Configuration > Policies > Windows Settings > Scripts (Startup/Shutdown) > Startup**.
3. Click **Show Files**. Place the collector, batch launcher, common helper and client `inventory.config.json` together in that protected script folder. Click **Add > Browse**, select `Collect-FullInventory.bat`, and leave parameters blank. Keep package writes restricted to administrators.
4. For each pilot PC, provision the device folder and grant that computer account (for example `CONTOSO\PC-001$`) rights to its folder. Grant its group SMB Change access and grant NTFS access as described in [Security](SECURITY.md). Configure a startup environment with network available if needed and test on the actual network.
5. Run `gpupdate /force` on the pilot, reboot, check computer policy via `gpresult /r /scope computer`, inspect the local status log, and verify the resulting submission and merge.

Startup runs under Local System, which normally uses the domain computer account for SMB. It suits device-only data and gives each client a distinct network principal. It still needs connectivity and permission to read the GPO files and publish to its own device folder. Laptops starting off-network may miss a collection. A managed scheduled retry can be useful.

## User logon, as shown in the Reel

In a user-scoped pilot GPO, use **User Configuration > Policies > Windows Settings > Scripts (Logon/Logoff) > Logon** and follow the same Show Files and Add steps. Link and scope it to the pilot users. Test with a standard user on each device they use. Log off and back on. Review user policy with `gpresult /r /scope user`.

The script runs as the signed-in user. Its local CIM read and SMB access depend on that user and machine policy. The same user may be authorized for multiple computer folders, so shared logon identity weakens device isolation. Use startup with computer-account permissions where isolation matters. The collector needs no elevation solely to call the default Win32 inventory queries, subject to endpoint WMI security configuration. Test the actual policy and execution context. The launcher honors PowerShell execution policy; deploy through your organization's signing and trust process.

- [Microsoft Group Policy startup and logon script guidance](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn789196(v=ws.11))
- [Microsoft policy settings for scripts](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-admx-scripts)
