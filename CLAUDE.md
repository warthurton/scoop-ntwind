# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Repository

This is a Scoop bucket template repository for creating custom Windows package installers. Scoop is a Windows command-line installer that allows users to install applications from "buckets" (repositories containing app manifest files).

## Key Commands

### Testing
- `pwsh bin/test.ps1` - Run all tests using Pester framework
- `pwsh Scoop-Bucket.Tests.ps1` - Run bucket-specific tests (imports from Scoop's test framework)

### Validation Scripts
- `pwsh bin/checkver.ps1` - Check for version updates across manifests
- `pwsh bin/checkhashes.ps1` - Verify file hashes in manifests
- `pwsh bin/checkurls.ps1` - Validate URLs in manifests
- `pwsh bin/formatjson.ps1` - Format JSON manifests consistently
- `pwsh bin/missing-checkver.ps1` - Find manifests missing version checking
- `pwsh bin/auto-pr.ps1` - Create automatic pull requests for updates

## Architecture

### Directory Structure
- `bucket/` - Contains app manifest JSON files (one per application)
- `bin/` - PowerShell scripts for maintenance and validation
- `deprecated/` - Deprecated manifests
- `scripts/` - Additional utility scripts

### Manifest Files
App manifests are JSON files in the `bucket/` directory that define:
- Application metadata (version, description, homepage, license)
- Download URLs and hashes for different architectures (64bit, 32bit, arm64)
- Installation/uninstallation scripts
- Binary paths and environment variables
- Auto-update configuration

Use `bucket/app-name.json.template` as a starting point for new manifests.

## Development Workflow

1. Copy `bucket/app-name.json.template` to `bucket/<app-name>.json`
2. Fill in the manifest fields with application details
3. Test the manifest with `pwsh bin/test.ps1`
4. Validate URLs and hashes with the validation scripts
5. Format JSON with `pwsh bin/formatjson.ps1`

## Requirements

- PowerShell 5.1 or later
- Pester module (version 5.2.0+) for testing
- BuildHelpers module (version 2.0.1+) for testing
- Scoop installed on the system for testing
