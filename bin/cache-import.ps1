<#
.SYNOPSIS
    Adds a manually downloaded file to the Scoop cache so 'scoop install' can find it.
.DESCRIPTION
    Some download URLs are blocked by Cloudflare and cannot be fetched automatically
    by Scoop. Download the file manually in a browser, then run this script to place
    it in the Scoop cache with the correct filename.
.VERSION 1.0.0
.PARAMETER Manifest
    The manifest name (e.g. 'wincam') or path to a .json manifest file.
.PARAMETER Download
    Path to the manually downloaded installer file.
.EXAMPLE
    scoop cache-import wincam C:\Users\you\Downloads\WinCam_4.0-setup.exe
#>
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Manifest,

    [Parameter(Mandatory, Position = 1)]
    [string]$Download
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Locate Scoop root/cache dir up front, since it's also used to search installed buckets
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }

# Resolve manifest path: an explicit file, this repo checkout (for maintainers), or
# any bucket already added to the local Scoop installation (when run as `scoop cache-import`)
if (Test-Path $Manifest -PathType Leaf) {
    $manifestPath = Resolve-Path $Manifest | Select-Object -ExpandProperty Path
} else {
    $name = $Manifest -replace '\.json$', ''
    $repoManifestPath = Join-Path $PSScriptRoot "..\bucket\$name.json"
    $bucketMatch = Get-ChildItem (Join-Path $scoopRoot 'buckets\*\bucket\*.json') -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -eq $name } |
        Select-Object -First 1

    if (Test-Path $repoManifestPath) {
        $manifestPath = Resolve-Path $repoManifestPath | Select-Object -ExpandProperty Path
    } elseif ($bucketMatch) {
        $manifestPath = $bucketMatch.FullName
    } else {
        Write-Error "Manifest not found: $Manifest"
        exit 1
    }
}

if (-not (Test-Path $Download)) {
    Write-Error "File not found: $Download"
    exit 1
}
$downloadPath = Resolve-Path $Download | Select-Object -ExpandProperty Path

$app  = [IO.Path]::GetFileNameWithoutExtension($manifestPath)
$data = Get-Content $manifestPath -Raw | ConvertFrom-Json

$version = $data.version
$url     = $data.url

if (-not $url) {
    Write-Error "'$app' has no top-level url (architecture-specific urls are not supported by this script)"
    exit 1
}

# Verify hash if the manifest includes one
if ($data.hash) {
    $hashValue = $data.hash
    if ($hashValue -match '^(sha256|sha512|sha1|md5):(.+)$') {
        $algorithm = $Matches[1].ToUpper()
        $expected  = $Matches[2].ToLower()
    } else {
        $algorithm = 'SHA256'
        $expected  = $hashValue.ToLower()
    }

    Write-Host "Verifying $algorithm hash..."
    $actual = (Get-FileHash $downloadPath -Algorithm $algorithm).Hash.ToLower()
    if ($actual -ne $expected) {
        Write-Error "Hash mismatch!`n  Expected: $expected`n  Actual:   $actual"
        exit 1
    }
    Write-Host "Hash OK"
}

# Compute cache filename: <app>#<version>#<sha256(url)[0..6]>.<ext>
$urlBytes  = [Text.Encoding]::UTF8.GetBytes($url)
$sha       = [Security.Cryptography.SHA256]::Create()
$urlHash   = ($sha.ComputeHash($urlBytes) | ForEach-Object { $_.ToString('x2') }) -join ''
$urlPrefix = $urlHash.Substring(0, 7)
$ext       = [IO.Path]::GetExtension($url)  # e.g. ".exe"

$cacheFilename = "$app#$version#$urlPrefix$ext"

# Locate Scoop cache dir
$cacheDir = Join-Path $scoopRoot 'cache'
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
}

$dest = Join-Path $cacheDir $cacheFilename
Copy-Item -Path $downloadPath -Destination $dest -Force
Write-Host "Cached as: $dest"
Write-Host "Install:   scoop install $app"
