#Requires -Version 5.1

<#
.SYNOPSIS
    Detect excavator hash failures and create GitHub issues for human follow-up
.DESCRIPTION
    After excavator runs, this script checks each manifest to see if a newer version
    is available but the download URL is inaccessible (e.g. 403 Forbidden).
    When such a failure is detected, a GitHub issue is created so a human can
    manually update the manifest.
.PARAMETER BucketPath
    Path to the bucket directory. Defaults to ../bucket relative to script location.
.PARAMETER CreateIssues
    If set, creates GitHub issues for detected failures (requires GitHub CLI and credentials).
.EXAMPLE
    .\check-hash-failures.ps1
.EXAMPLE
    .\check-hash-failures.ps1 -CreateIssues
#>

param(
    [string]$BucketPath = (Join-Path $PSScriptRoot '..\bucket'),
    [switch]$CreateIssues
)

$script:HadErrors = $false

# Fetch the checkver URL and extract the latest version using the manifest regex
function Get-LatestVersion {
    param(
        [string]$CheckverUrl,
        [string]$CheckverRegex
    )

    try {
        $response = Invoke-WebRequest -Uri $CheckverUrl -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $regexMatch = [regex]::Match($response.Content, $CheckverRegex)
        if ($regexMatch.Success) {
            return $regexMatch.Groups[1].Value
        }
        return $null
    } catch {
        Write-Warning "Failed to fetch checkver URL ${CheckverUrl}: $_"
        return $null
    }
}

# Send a HEAD request to test whether a download URL is accessible
function Test-DownloadUrl {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        return @{
            Success    = $true
            StatusCode = [int]$response.StatusCode
            Error      = $null
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        return @{
            Success    = $false
            StatusCode = $statusCode
            Error      = $_.Exception.Message
        }
    }
}

# Create a GitHub issue reporting that the hash check failed for a package
function New-HashFailureIssue {
    param(
        [string]$AppName,
        [string]$NewVersion,
        [string]$CurrentVersion,
        [string]$DownloadUrl,
        [string]$ErrorMessage,
        [AllowNull()][object]$StatusCode
    )

    $title = "${AppName}: hash check failed for version ${NewVersion}"
    $statusInfo = if ($StatusCode) { "HTTP $StatusCode" } else { 'connection error' }

    $body = @"
Excavator attempted to update **$AppName** from version **$CurrentVersion** to **$NewVersion** but could not download the installer to compute the hash.

**Download URL:** $DownloadUrl
**Error:** ${statusInfo}: $ErrorMessage

## Details

The excavator automation could not access the download URL. This may be because:
- The server is blocking automated requests (e.g. 403 Forbidden)
- The download URL is temporarily unavailable
- The version has not yet been publicly released

## To-do
- [ ] Verify the download URL is accessible: $DownloadUrl
- [ ] Manually compute the hash and update the manifest
- [ ] Test installation: ``scoop install $AppName``
"@

    Write-Host "  Creating issue: $title"

    try {
        # Ensure the label exists before using it
        gh label create 'hash-check-failed' --description 'Excavator failed to compute hash' --color 'E4E669' --force 2>&1 | Out-Null

        # Skip if an open issue with the same title already exists
        $existingRaw = gh issue list --search "in:title `"$title`"" --json title,state --limit 100 2>&1
        if ($LASTEXITCODE -eq 0 -and $existingRaw) {
            $existing = $existingRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($existing | Where-Object { $_.state -eq 'OPEN' -and $_.title -eq $title }) {
                Write-Host "  Open issue already exists for $AppName - skipping"
                return
            }
        }

        gh issue create --title $title --body $body --label 'hash-check-failed' 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Issue created for $AppName"
        } else {
            Write-Error "  Failed to create issue for $AppName (gh exit code: $LASTEXITCODE)"
            $script:HadErrors = $true
        }
    } catch {
        Write-Error "  Exception creating issue for ${AppName}: $_"
        $script:HadErrors = $true
    }
}

# ── Main ────────────────────────────────────────────────────────────────────

Write-Host 'Checking for excavator hash failures...'
Write-Host ''

$manifests = Get-ChildItem -Path $BucketPath -Filter '*.json' |
    Where-Object { $_.Name -notmatch 'template' }

$failures = @()

foreach ($file in $manifests) {
    $appName = $file.BaseName

    try {
        $manifest = Get-Content $file.FullName -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to parse ${appName}: $_"
        continue
    }

    # Skip manifests without checkver or autoupdate sections
    if (-not $manifest.checkver -or -not $manifest.autoupdate) { continue }

    # Require a URL+regex checkver and a versioned autoupdate URL
    $checkverUrl   = $manifest.checkver.url
    $checkverRegex = $manifest.checkver.regex
    $urlTemplate   = $manifest.autoupdate.url

    if (-not $checkverUrl -or -not $checkverRegex) { continue }
    if (-not $urlTemplate -or $urlTemplate -notmatch '\$version') { continue }

    # Determine the latest available version from the upstream page
    $latestVersion = Get-LatestVersion -CheckverUrl $checkverUrl -CheckverRegex $checkverRegex
    if (-not $latestVersion) {
        Write-Verbose "  ${appName}: could not determine latest version"
        continue
    }

    # Compare with the version recorded in the manifest
    $currentVersion = $manifest.version
    try {
        $latestVer  = [System.Version]$latestVersion
        $currentVer = [System.Version]$currentVersion
        if ($latestVer -le $currentVer) {
            Write-Verbose "  ${appName}: up to date ($currentVersion)"
            continue
        }
    } catch {
        # Fall back to string comparison when version parsing fails
        if ($latestVersion -eq $currentVersion) { continue }
    }

    Write-Host "${appName}: new version $latestVersion available (current: $currentVersion)"

    # Construct the candidate download URL for the new version
    $newUrl = $urlTemplate -replace '\$version', $latestVersion

    # Check whether the URL is reachable
    $result = Test-DownloadUrl -Url $newUrl

    if ($result.Success) {
        Write-Host "  URL accessible (HTTP $($result.StatusCode)) - excavator failure may have been transient"
    } else {
        $statusInfo = if ($result.StatusCode) { "HTTP $($result.StatusCode)" } else { 'no response' }
        Write-Host "  URL NOT accessible (${statusInfo}): $($result.Error)"
        $failures += @{
            AppName         = $appName
            NewVersion      = $latestVersion
            CurrentVersion  = $currentVersion
            DownloadUrl     = $newUrl
            ErrorMessage    = $result.Error
            StatusCode      = $result.StatusCode
        }
    }
}

Write-Host ''

if ($failures.Count -eq 0) {
    Write-Host 'No hash failures requiring human intervention.'
} else {
    Write-Host "$($failures.Count) package(s) have inaccessible download URLs requiring human intervention:"

    foreach ($failure in $failures) {
        Write-Host "  - $($failure.AppName) $($failure.NewVersion)"

        if ($CreateIssues) {
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                New-HashFailureIssue @failure
            } else {
                Write-Warning 'GitHub CLI (gh) not found. Cannot create issues.'
                $script:HadErrors = $true
                break
            }
        }
    }
}

if ($script:HadErrors) {
    exit 1
}

exit 0
