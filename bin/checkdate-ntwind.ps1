#Requires -Version 5.1

<#!
.SYNOPSIS
    Extracts the last updated date for NTWind applications from their homepage.
.DESCRIPTION
    This script fetches the homepage of an NTWind application and searches for the pattern
    "Updated on YYYY-MM-DD" to determine the last application version update date.
.PARAMETER HomepageUrl
    The URL of the application's homepage.
.EXAMPLE
    .\checkdate-ntwind.ps1 -HomepageUrl "https://www.ntwind.com/software/winsnap.html"
#>

param(
    [Parameter(Mandatory)]
    [string]$HomepageUrl
)

try {
    # Fetch the homepage content
    $webContent = Invoke-WebRequest -Uri $HomepageUrl -UseBasicParsing

    # Search for the "Updated on YYYY-MM-DD" pattern
    if ($webContent.Content -match 'Updated on (?<date>\d{4}-\d{2}-\d{2})') {
        Write-Output $matches['date']
    } else {
        Write-Warning "No updated date found on the homepage."
    }
} catch {
    Write-Error "Failed to fetch or parse the homepage: $_"
}
