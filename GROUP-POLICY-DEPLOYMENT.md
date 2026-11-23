# Group Policy deployment

## Device inventory at startup

1. On an admin workstation open Group Policy Management. Create and link a test GPO to an OU containing pilot computers. Scope it to those computers.
2. Edit **Computer Configuration > Policies > Windows Settings > Scripts (Startup/Shutdown) > Startup**.
3. Click **Show Files**. Place the collector, batch launcher, common helper and client `inventory.config.json` together in that protected script folder. Click **Add > Browse**, select `Collect-FullInventory.bat`, and leave parameters blank. Keep package writes restricted to administrators.
4. For each pilot PC, provision the device folder and grant that computer account (for example `CONTOSO\PC-001$`) rights to its folder. Grant its group SMB Change access and grant NTFS access as described in [Security](SECURITY.md). Configure a startup environment with network available if needed and test on the actual network.
5. Run `gpupdate /force` on the pilot, reboot, check computer policy via `gpresult /r /scope computer`, inspect the local status log, and verify the resulting submission and merge.

Startup runs under Local System, which normally uses the domain computer account for SMB. It suits device-only data and gives each client a distinct network principal. It still needs connectivity and permission to read the GPO files and publish to its own device folder. Laptops starting off-network may miss a collection. A managed scheduled retry can be useful.

## Create, configure, and pilot a startup GPO

### 1. Create the GPO without linking it

1. On an authorized Windows admin workstation with the Group Policy Management tools installed, press Windows+R, enter `gpmc.msc`, and select OK.
2. In Group Policy Management, expand **Forest > Domains > contoso.com > Group Policy Objects**. Right-click **Group Policy Objects**, select **New**, and name the GPO `Computer-Inventory-Collection`.
3. Creating the GPO stores the settings in the domain. Linking it to an OU makes it eligible to apply there. Leave it unlinked while preparing it. Start with a pilot OU containing a few approved IT computer objects so you can verify access and output before broader rollout.

### 2. Configure the startup script

1. Right-click `Computer-Inventory-Collection` under **Group Policy Objects**, and select **Edit**.
2. Open **Computer Configuration > Policies > Windows Settings > Scripts (Startup/Shutdown) > Startup**.
3. Open **Startup** and select **Show Files**. In the policy's startup script folder, place these four files together:

   - `Collect-FullInventory.bat`
   - `Collect-FullInventory.ps1`
   - `Inventory-Common.ps1`
   - `inventory.config.json` configured for the clients

4. Return to Startup Properties. Select **Add > Browse**, select `Collect-FullInventory.bat`, and leave **Script Parameters** blank. Select **OK** to save.
5. Reopen **Show Files** and verify that the four names and extensions are correct. The BAT uses Windows PowerShell 5.1 and launches the collector from the BAT's folder. The collector loads the adjacent helper and defaults to the adjacent config file. The merge script stays on the server.

Set the client config to use the approved SMB inbox and writable local staging and log paths. Restrict changes to the GPO and its files to authorized administrators. Computer accounts need read access to the policy and its files in SYSVOL. The launcher follows execution policy. Use your approved signing and trust process.

## Link the GPO to departmental computer OUs

Example Active Directory OU structure:

```text
contoso.com
  Department-Computers
    HR-Computers
    Finance-Computers
    IT-Computers
    Admissions-Computers
```

**Computer startup policy follows the OU of the computer object.** A user's account being in the HR OU does not make the user's computer eligible for that OU's startup policy.

### A. Link to individual departments

1. In GPMC, expand **Domains > contoso.com > Department-Computers** and locate the pilot computer OU. If the IT department OU contains more computers than the pilot, use a dedicated pilot OU or a security filter limited to the pilot computer accounts.
2. Right-click the target OU and select **Link an Existing GPO**. Select `Computer-Inventory-Collection` and select **OK**. Confirm the new link is enabled and the computer settings are enabled.
3. After validating the pilot, repeat **Link an Existing GPO** for each approved department OU in turn. Use the same GPO. An edit to that GPO affects every OU where it applies.

Individual links are useful when departments roll out on different dates or some OUs should stay out of scope.

### B. Link to the common parent

When all intended child OUs are ready, link the existing GPO to **Department-Computers** and verify inheritance in each child OU. An enabled parent link can also reach computers directly in that parent and future child OUs, subject to filtering and inheritance. Inspect the entire subtree before linking. Review existing department links before removing any redundant links to this GPO. A parent link suits a common policy across an approved subtree.

## Set permissions and verify inheritance

### Security filtering and file access

In GPMC, select the GPO and review **Scope > Security Filtering**. For a pilot tighter than the linked OU, use a security group containing only the approved computer accounts. The target computers need **Read** and **Apply Group Policy**. Verify the effective permissions under **Delegation > Advanced**. If the default **Authenticated Users** entry still grants Apply, the pilot group alone does not narrow the scope. Preserve read access needed to process the policy while reviewing which principals have Apply. Test policy processing after changing membership. A restart can be needed to refresh the computer's group membership.

GPO filtering controls policy application. It does not grant write access to the inventory data. Verify these separately:

- **SYSVOL:** Target computer accounts need to read the policy and its script files. Only authorized administrators should edit them.
- **SMB share:** Give scoped submitters the required share access, for example SMB Change, then enforce the folder boundary with NTFS.
- **NTFS inbox:** Pre-create one folder per computer name before rollout. The collector checks for it and does not create it. For example, grant `CONTOSO\PC-001$` Modify in its own `PC-001` folder at `\\fileserver.contoso.com\ComputerInventory$`. Scope root traversal as needed, keep the master outside the inbox, and follow [Security](SECURITY.md).
- Do not grant **Domain Computers** or **Authenticated Users** broad inherited write access to every folder. Test with two computer identities. Each should write only to its own inbox, and neither should alter the master.

### Links, precedence, and inheritance

Normally, policy from parent OUs is inherited and child OU policy can take precedence for conflicting settings. More than one GPO can apply. On the same OU, link order 1 has highest precedence by default. Separate startup script assignments can coexist.

**Block Inheritance** on an OU blocks ordinary inherited links. **Enforced** is a link property that survives a block and prevents lower-level conflicting settings from overriding that link. In GPMC, inspect the OU's **Group Policy Inheritance** tab and use client results to confirm actual application. Check the computer's OU, link and computer settings status, filtering, and denied policies. Avoid changing unrelated link order, Block Inheritance, or Enforced settings to make this toolkit work.

## Roll out and verify the collector

1. Pilot with a few authorized IT computers. Confirm each can create its CSV and cannot write in another device's inbox or the master folder.
2. Expand to one additional department. Verify policy, submissions, and merge results before continuing department by department. Monitor collection errors, submission age, and missing devices.

On an approved test PC, use an elevated Command Prompt to refresh policy and inspect computer results:

```cmd
gpupdate /force
gpresult /r /scope computer
gpresult /h "%TEMP%\Inventory-GPO.html" /f
```

`gpupdate /force` refreshes policy and does not itself run the startup script. Restart the pilot computer while connected to the domain network. After restart, inspect **Computer Configuration** in the HTML report, including applied and denied GPOs. In Event Viewer, open **Applications and Services Logs > Microsoft > Windows > GroupPolicy > Operational** and check events from that startup.

Check that the computer account can read SYSVOL and reach the SMB share at startup. A successful test under your admin account does not establish startup access. In the configured local `LogRoot`, check `collect-*.log` for `SUBMITTED`; confirm a new `submission-*.csv` in the device folder and verify the next merge includes the PC. If the launcher or config fails before logging is available, check Group Policy events, execution policy, and the configured local paths.

A missing device folder in the collector's PowerShell 5.1 lookup returns `CONFIGURATION_OR_VALIDATION_FAILURE`. Check the exact name and provision the folder. `PATH_UNAVAILABLE` covers a filesystem file/directory-not-found exception; `ACCESS_DENIED` covers access or security exceptions; `IO_OR_LOCK_FAILURE` covers other I/O errors. See [Troubleshooting](TROUBLESHOOTING.md).

### Startup versus user logon

Computer startup runs as **Local System** and normally uses the **domain computer account** for network access. It supports per-device SMB isolation. The Reel's user logon option runs under the **signed-in user**, who needs their own local CIM and SMB permissions. If one user can access multiple device folders, logon provides weaker isolation. Keep the two deployment methods distinct.

- [Microsoft Group Policy processing and inheritance](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-processing)
- [Microsoft Group Policy troubleshooting guidance](https://learn.microsoft.com/troubleshoot/windows-server/group-policy/applying-group-policy-troubleshooting-guidance)

## User logon, as shown in the Reel

In a user-scoped pilot GPO, use **User Configuration > Policies > Windows Settings > Scripts (Logon/Logoff) > Logon** and follow the same Show Files and Add steps. Link and scope it to the pilot users. Test with a standard user on each device they use. Log off and back on. Review user policy with `gpresult /r /scope user`.

The script runs as the signed-in user. Its local CIM read and SMB access depend on that user and machine policy. The same user may be authorized for multiple computer folders, so shared logon identity weakens device isolation. Use startup with computer-account permissions where isolation matters. The collector needs no elevation solely to call the default Win32 inventory queries, subject to endpoint WMI security configuration. Test the actual policy and execution context. The launcher honors PowerShell execution policy; deploy through your organization's signing and trust process.

- [Microsoft Group Policy startup and logon script guidance](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn789196(v=ws.11))
- [Microsoft policy settings for scripts](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-admx-scripts)
