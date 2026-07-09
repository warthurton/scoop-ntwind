#Requires -Version 5.1

<#
.SYNOPSIS
    Check for new NTWind applications and create GitHub issues for them
.DESCRIPTION
    This script fetches the NTWind download page, identifies new applications
    that aren't yet in the bucket, and creates GitHub issues for them.
    Runs weekly to monitor for new NTWind applications.
.PARAMETER DownloadPageUrl
    URL of the NTWind download page. Defaults to https://www.ntwind.com/download-all.html
.PARAMETER BucketPath
    Path to the bucket directory. Defaults to ../bucket relative to script location.
.PARAMETER CreateIssues
    If set, creates GitHub issues for new applications (requires GitHub CLI and credentials).
.EXAMPLE
    .\check-new-applications.ps1
.EXAMPLE
    .\check-new-applications.ps1 -CreateIssues
#>

param(
    [string]$DownloadPageUrl = 'https://www.ntwind.com/download-all.html',
    [string]$BucketPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\bucket'),
    [switch]$CreateIssues
)

# Track script-level errors so CI can fail only on real failures
$script:HadErrors = $false

# Get list of existing applications in the bucket
function Get-BucketApplications {
    param([string]$BucketPath)

    $apps = @{}

    if (-not (Test-Path $BucketPath)) {
        return $apps
    }

    $jsonFiles = Get-ChildItem -Path $BucketPath -Filter '*.json' |
        Where-Object { $_.Name -notmatch 'template' }

    foreach ($file in $jsonFiles) {
        try {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $appName = $file.BaseName
            $apps[$appName] = @{
                path     = $file.FullName
                manifest = $content
            }
        } catch {
            Write-Warning "Failed to parse $($file.Name): $($_)"
            $script:HadErrors = $true
        }
    }

    return $apps
}

# Fetch and parse the download page to find applications
function Get-AvailableApplications {
    param([string]$Url)

    try {
        Write-Host "Fetching NTWind download page from: $Url"
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        $html = $response.Content

        # Parse HTML to find application links and information
        # Look for download links and application information patterns
        $downloadPattern = '/download/(?<file>[^"'']+)'
        $matches = [regex]::Matches($html, $downloadPattern)

        $apps = @{}

        foreach ($match in $matches) {
            $fileName = $match.Groups['file'].Value

            # Try to extract application name from file name
            # Example: "AltTabTer_6.6-setup.exe" -> "alt-tab-terminator"
            $appName = Get-ApplicationNameFromFileName $fileName

            if ($appName -and -not $apps.ContainsKey($appName)) {
                $apps[$appName] = @{
                    fileName = $fileName
                    url      = "https://www.ntwind.com/download/$fileName"
                }
            }
        }

        return $apps
    } catch {
        Write-Error "Failed to fetch download page: $($_)"
        $script:HadErrors = $true
        return @{}
    }
}

# Map file names to bucket application names
function Get-ApplicationNameFromFileName {
    param([string]$FileName)

    # Map of common file name patterns to bucket names
    $nameMap = @{
        'AltTabTer'        = 'alt-tab-terminator'
        'BadApp'           = 'bad-application'
        'Clipaste'         = 'clipaste'
        'ClipboardRemote'  = 'clipboard-remote'
        'CloseAll'         = 'close-all-windows'
        'Hstart'           = 'hidden-start'
        'HotkeyScreener'   = 'hotkey-screener'
        'MediaRemote'      = 'media-remote'
        'PowerRemote'      = 'power-remote'
        'PromptSense'      = 'promptsense'
        'ScreenshotRemote' = 'screenshot-remote'
        'StickyPreviews'   = 'sticky-previews'
        'TaskSwitchXP'     = 'taskswitchxp'
        'UploadRemote'     = 'upload-remote'
        'VistaSwitcher'    = 'vistaswitcher'
        'VSubst'           = 'visual-subst'
        'WinCam'           = 'wincam'
        'WindowSpace'      = 'windowspace'
        'WinSnap'          = 'winsnap'
        'WndFromPoint'     = 'wndfrompoint'
        'WorkspaceCover'   = 'workspacecover'
    }

    foreach ($pattern in $nameMap.Keys) {
        if ($FileName -like "$pattern*") {
            return $nameMap[$pattern]
        }
    }

    return $null
}

# Create a GitHub issue for a new application
function New-GitHubIssue {
    param(
        [string] $appName,
        [string] $fileName,
        [string] $url
    )

    $title = "Add $appName to bucket"
    $body = @"
New NTWind application detected: **$appName**

**File:** $fileName
**Download URL:** $url

This application was found on https://www.ntwind.com/download-all.html but is not yet in the bucket.

## To-do
- [ ] Create manifest for $appName
- [ ] Verify application details
- [ ] Test installation via Scoop
"@

    Write-Host "Creating issue for $appName..."

    # Check if issue already exists for this application
    try {
        $existingIssues = gh issue list --search "title:""$title""" --json title,state --limit 100 2>$null

        if ($existingIssues | ConvertFrom-Json | Where-Object { $_.state -eq 'OPEN' }) {
            Write-Host "  Issue already exists for $appName (skipping)"
            return
        }

        gh issue create --title $title --body $body 2>$null | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create issue for $appName (gh exit code: $LASTEXITCODE)"
            $script:HadErrors = $true
            return
        }

        Write-Host "  Issue created for $appName"
    } catch {
        Write-Error ("Failed to create issue for {0}: {1}" -f $appName, $_)
        $script:HadErrors = $true
    }
}

# Main script
Write-Host "Checking for new NTWind applications..."
Write-Host ""

$bucketApps = Get-BucketApplications $BucketPath
Write-Host ('Found {0} applications in bucket' -f $bucketApps.Count)

$availableApps = Get-AvailableApplications $DownloadPageUrl
Write-Host ('Found {0} applications available for download' -f $availableApps.Count)
Write-Host ""

$newApps = @{}
foreach ($appName in $availableApps.Keys) {
    if (-not $bucketApps.ContainsKey($appName)) {
        $newApps[$appName] = $availableApps[$appName]
    }
}

if ($newApps.Count -eq 0) {
    Write-Host "No new applications found"
} else {
    Write-Host ('Found {0} new application(s):' -f $newApps.Count)
    foreach ($appName in $newApps.Keys | Sort-Object) {
        $app = $newApps[$appName]
        Write-Host ('  - {0} ({1})' -f $appName, $app.fileName)
        if ($CreateIssues -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            New-GitHubIssue -appName $appName -fileName $app.fileName -url $app.url
        }
    }

    if ($CreateIssues -and -not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning 'GitHub CLI (gh) not found. Skipping issue creation.'
        Write-Host 'Install GitHub CLI from: https://cli.github.com/'
        $script:HadErrors = $true
    }
}

if ($script:HadErrors) {
    Write-Error 'One or more errors occurred while checking for new applications.'
    exit 1
}

Write-Host 'Check completed successfully.'
exit 0
