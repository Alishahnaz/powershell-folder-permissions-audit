
# PROJECT: Windows Folder Permissions Audit
# Purpose: Identify folders with Everyone permissions
# Mode: Read-only audit

# 1. Set folder locations
[CmdletBinding()]
param(
    [string]$RootFolder = (Join-Path $HOME "PermissionsAuditDemo"),
    [string]$ReportFolder = (Join-Path $HOME "PermissionsAuditReports")
)

# 2. Check that the practice folder exists
if (-not (Test-Path -LiteralPath $RootFolder -PathType Container)) {
    throw "Folder not found: $RootFolder"
}

# 3. Create the reports directory
New-Item -ItemType Directory -Path $ReportFolder `
    -Force -ErrorAction Stop | Out-Null

# 4. Collect the main folder and subfolders
$discoveryErrors = @()
$auditFailures = 0
$allFolders = @(Get-Item -LiteralPath $RootFolder -ErrorAction Stop) +
    @(Get-ChildItem -LiteralPath $RootFolder `
        -Directory -Recurse -Force -ErrorAction SilentlyContinue `
        -ErrorVariable +discoveryErrors)

foreach ($discoveryError in $discoveryErrors) {
    Write-Warning "Folder discovery was incomplete: $discoveryError"
}

# 5. Examine permissions for every folder
$results = foreach ($folder in $allFolders) {
    try {
        $acl = Get-Acl -LiteralPath $folder.FullName `
            -ErrorAction Stop

        foreach ($rule in $acl.Access) {
            $account = $rule.IdentityReference.Value

            # Resolve Windows security identifier
            $sid = ""
            try {
                $sid = $rule.IdentityReference.Translate(
                    [System.Security.Principal.SecurityIdentifier]
                ).Value
            }
            catch {
                # Continue using the account name
            }

            # Everyone has the well-known SID S-1-1-0
            $isEveryone = (
                $sid -eq "S-1-1-0" -or
                $account -eq "Everyone" -or
                $account -eq "S-1-1-0"
            )

            $needsReview = (
                $isEveryone -and
                $rule.AccessControlType -eq "Allow"
            )

            # Record each permission rule
            [PSCustomObject]@{
                Folder          = $folder.FullName
                AccountOrGroup  = $account
                Permission      = [string]$rule.FileSystemRights
                RuleType        = [string]$rule.AccessControlType
                Inherited       = $rule.IsInherited
                EveryoneFlag    = if ($needsReview) {
                    "REVIEW"
                } else {
                    "Not flagged"
                }
            }
        }
    }
    catch {
        $auditFailures++
        Write-Warning "Unable to audit $($folder.FullName): $_"
    }
}

$results = @($results)

if ($results.Count -eq 0) {
    throw "No permission records were collected."
}

# 6. Create timestamped report filenames
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss_fff"

$allReport = Join-Path $ReportFolder `
    "AllPermissions_$timestamp.csv"

$flagReport = Join-Path $ReportFolder `
    "EveryoneFindings_$timestamp.csv"

# 7. Export the complete audit
$results | Export-Csv -LiteralPath $allReport `
    -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop

# 8. Export folders needing review
$findings = @(
    $results | Where-Object {
        $_.EveryoneFlag -eq "REVIEW"
    }
)

if ($findings.Count -gt 0) {
    $findings | Export-Csv -LiteralPath $flagReport `
        -NoTypeInformation -Encoding UTF8 -NoClobber -ErrorAction Stop
}
else {
    # Create a report containing just column headings
    $header = $results | Select-Object -First 1 |
        ConvertTo-Csv -NoTypeInformation | Select-Object -First 1
    $header | Out-File -LiteralPath $flagReport `
        -Encoding UTF8 -NoClobber -ErrorAction Stop
}

# 9. Display a summary
$flaggedFolders = @(
    $findings | Select-Object -ExpandProperty Folder -Unique
)

Write-Host ""
Write-Host "FOLDER PERMISSIONS AUDIT COMPLETE"
Write-Host "---------------------------------"
Write-Host "Folders discovered: $($allFolders.Count)"
Write-Host "Folder discovery errors: $($discoveryErrors.Count)"
Write-Host "Folders unable to audit: $auditFailures"
if ($discoveryErrors.Count -gt 0 -or $auditFailures -gt 0) {
    Write-Warning "Audit coverage is incomplete. Review the warnings before interpreting zero findings."
}
Write-Host "Permission rules: $($results.Count)"
Write-Host "Folders flagged: $($flaggedFolders.Count)"
Write-Host ""
Write-Host "All permissions: $allReport"
Write-Host "Everyone findings: $flagReport"
