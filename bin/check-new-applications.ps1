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
    [string]$BucketPath = (Join-Path $PSScriptRoot '..' 'bucket'),
    [switch]$CreateIssues
)

# Get list of existing applications in the bucket
function Get-BucketApplications {
    param([string]$BucketPath)
    
    $apps = @{}
    $jsonFiles = Get-ChildItem -Path $BucketPath -Filter '*.json' -Exclude '*template*', '*bad-application*'
    
    foreach ($file in $jsonFiles) {
        $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $appName = $file.BaseName
        $apps[$appName] = @{
            path = $file.FullName
            manifest = $content
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
                    url = "https://www.ntwind.com/download/$fileName"
                }
            }
        }
        
        return $apps
    } catch {
        Write-Error "Failed to fetch download page: $_"
        return @{}
    }
}

# Map file names to bucket application names
function Get-ApplicationNameFromFileName {
    param([string]$FileName)
    
    # Map of common file name patterns to bucket names
    $nameMap = @{
        'AltTabTer'       = 'alt-tab-terminator'
        'BadApp'          = 'bad-application'
        'Clipaste'        = 'clipaste'
        'ClipboardRemote' = 'clipboard-remote'
        'CloseAll'        = 'close-all-windows'
        'Hstart'          = 'hidden-start'
        'HotkeyScreener'  = 'hotkey-screener'
        'ScreenshotRemote'= 'screenshot-remote'
        'StickyPreviews'  = 'sticky-previews'
        'TaskSwitchXP'    = 'taskswitchxp'
        'UploadRemote'    = 'upload-remote'
        'VistaSwitcher'   = 'vistaswitcher'
        'VSubst'          = 'visual-subst'
        'WinCam'          = 'wincam'
        'WindowSpace'     = 'windowspace'
        'WinSnap'         = 'winsnap'
        'WndFromPoint'    = 'wndfrompoint'
        'WorkspaceCover'  = 'workspacecover'
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
        [string]$AppName,
        [string]$FileName,
        [string]$Url
    )
    
    $title = "Add $appName to bucket"
    $body = @"
New NTWind application detected: **$appName**

**File:** ``$FileName``
**Download URL:** $Url

This application was found on https://www.ntwind.com/download-all.html but is not yet in the bucket.

## To-do
- [ ] Create manifest for ``$appName``
- [ ] Verify application details
- [ ] Test installation via Scoop
- [ ] Update APPLICATIONS.md if automated generation is re-enabled
"@

    try {
        Write-Host "Creating issue for $appName..."
        
        # Check if issue already exists for this application
        $existingIssues = gh issue list --search "title:""$title""" --json title,state --limit 100 2>$null
        
        if ($existingIssues | ConvertFrom-Json | Where-Object { $_.state -eq 'OPEN' }) {
            Write-Host "  Issue already exists for $appName (skipping)"
            return
        }
        
        $escapedBody = $body -replace '"', '\"' -replace "`n", '\n'
        gh issue create --title $title --body $body --assignee @me 2>$null
        
        Write-Host "  ✓ Issue created for $appName"
    } catch {
        Write-Error "Failed to create issue for $appName: $_"
    }
}

# Main script
Write-Host "Checking for new NTWind applications..."
Write-Host ""

$bucketApps = Get-BucketApplications $BucketPath
Write-Host "Found $($bucketApps.Count) applications in bucket"

$availableApps = Get-AvailableApplications $DownloadPageUrl
Write-Host "Found $($availableApps.Count) applications available for download"
Write-Host ""

$newApps = @{}
foreach ($appName in $availableApps.Keys) {
    if (-not $bucketApps.ContainsKey($appName)) {
        $newApps[$appName] = $availableApps[$appName]
    }
}

if ($newApps.Count -eq 0) {
    Write-Host "✓ No new applications found"
} else {
    Write-Host "Found $($newApps.Count) new application(s):"
    foreach ($appName in $newApps.Keys | Sort-Object) {
        $app = $newApps[$appName]
        Write-Host "  - $appName ($($app.fileName))"
        
        if ($CreateIssues -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            New-GitHubIssue -AppName $appName -FileName $app.fileName -Url $app.url
        }
    }
    
    if ($CreateIssues -and -not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning "GitHub CLI (gh) not found. Skipping issue creation."
        Write-Host "Install GitHub CLI from: https://cli.github.com/"
    }
}
