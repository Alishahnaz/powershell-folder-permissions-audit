$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'FolderPermissionsAudit.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('audit-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
function Get-Acl {
    param($LiteralPath, $ErrorAction)
    if ($global:auditTestFailAcl) { throw 'Simulated unreadable ACL' }
    [pscustomobject]@{ Access = @(
        [pscustomobject]@{
            IdentityReference = [System.Security.Principal.SecurityIdentifier]::new('S-1-1-0')
            FileSystemRights = 'ReadAndExecute'
            AccessControlType = $global:auditTestRuleType
            IsInherited = $false
        }
    ) }
}
$global:auditTestRuleType = 'Allow'
$allowReports = Join-Path $testRoot 'allow'
& $scriptPath -RootFolder $testRoot -ReportFolder $allowReports
$finding = @(Import-Csv (Get-ChildItem $allowReports -Filter 'EveryoneFindings*').FullName)
if ($finding.Count -lt 1 -or $finding[0].EveryoneFlag -ne 'REVIEW') { throw 'Everyone Allow was not flagged' }
$global:auditTestRuleType = 'Deny'
$denyReports = Join-Path $testRoot 'deny'
& $scriptPath -RootFolder $testRoot -ReportFolder $denyReports
$emptyReport = (Get-ChildItem $denyReports -Filter 'EveryoneFindings*').FullName
if (@(Import-Csv $emptyReport).Count -ne 0) { throw 'Everyone Deny was incorrectly flagged' }
if ((Get-Content $emptyReport -Raw) -notmatch '"Folder","AccountOrGroup","Permission","RuleType","Inherited","EveryoneFlag"') { throw 'Empty report has no header' }
$missingFailed = $false
try { & $scriptPath -RootFolder (Join-Path $testRoot 'missing') } catch { $missingFailed = $true }
if (-not $missingFailed) { throw 'Missing root did not fail' }
$global:auditTestFailAcl = $true
$aclFailed = $false
try { & $scriptPath -RootFolder $testRoot -ReportFolder (Join-Path $testRoot 'unreadable') -WarningAction SilentlyContinue } catch { $aclFailed = $true }
if (-not $aclFailed) { throw 'Zero collected records did not fail' }
$global:auditTestFailAcl = $false
function Get-Date { param($Format) 'fixed-timestamp' }
$collisionReports = Join-Path $testRoot 'collision'
& $scriptPath -RootFolder $testRoot -ReportFolder $collisionReports
$before = Get-Content (Join-Path $collisionReports 'AllPermissions_fixed-timestamp.csv') -Raw
$collisionFailed = $false
try { & $scriptPath -RootFolder $testRoot -ReportFolder $collisionReports } catch { $collisionFailed = $true }
if (-not $collisionFailed) { throw 'Report collision did not fail' }
if ($before -cne (Get-Content (Join-Path $collisionReports 'AllPermissions_fixed-timestamp.csv') -Raw)) { throw 'Existing report changed' }
Write-Output 'PASS: syntax, Everyone Allow/Deny, header-only CSV, missing root, unreadable ACL, and report collision protection.'
