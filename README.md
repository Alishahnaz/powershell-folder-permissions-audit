# Windows Folder Permissions Audit (PowerShell)

A PowerShell script that lists the NTFS permissions on a folder and its subfolders, flags any Allow entry granted to the Everyone group, and writes the results to CSV.

## Why

Folder permissions drift over time, and checking them by hand across many folders is slow and easy to get wrong. A script produces the same report every time it runs, so the output from before a fix can be compared directly with the output from after it.

## What it does

1. Scans a target folder and all of its subfolders.
2. Reads each folder's access-control entries with `Get-Acl`.
3. Records the account or group, permission level, rule type (Allow or Deny) and whether the entry is inherited.
4. Flags Allow entries for Everyone, matched by security identifier rather than display name.
5. Writes two timestamped CSV files: a full inventory and a list of flagged entries.

The script only reads permissions. It does not change them.

## Requirements

A Windows computer with PowerShell, and read access to the folders you want to audit. `icacls` was used only to set up the test case described below.

## Running the demo

1. Download `FolderPermissionsAudit.ps1`.
2. Create a folder named `PermissionsAuditDemo` in your Windows user directory.
3. Inside it, create `Finance`, `HR` and `PublicShare`, then add a `Payroll` folder inside `Finance`.
4. Open PowerShell in the directory that contains the script.
5. Run:

   ```powershell
   .\FolderPermissionsAudit.ps1
   ```

6. Open the reports in `%USERPROFILE%\PermissionsAuditReports`.

## Output

Each run writes two files with a timestamp in the name.

`AllPermissions` lists every access-control entry found, with the folder path, account or group, permission level, rule type, inheritance status and the Everyone review flag.

`EveryoneFindings` lists only the entries flagged for review.

## Testing

### Test 1: Detecting an Everyone permission

An explicit Everyone ReadAndExecute permission was added to the `PublicShare` test folder. The audit found it and marked the entry `REVIEW`.

![Test 1 permission finding](screenshots/Test1_BeforeCorrection.png)

### Test 2: Confirming the fix

The permission was removed with `icacls` and the audit was run again. No entries were flagged.

![Test 2 audit result](screenshots/Test2_AfterCorrection.png)

Sample CSV output is in the `sample-reports` directory, with personal identifiers removed.

## Limitations

The script reads NTFS access-control entries only. It does not calculate effective access, expand nested group membership or assess SharePoint Online permissions.

A flagged Everyone entry means the folder needs a closer look. Whether anyone actually has unwanted access also depends on Deny rules, inheritance and group membership.

Folders the script cannot open or read may be missing from the report and should be checked separately.
