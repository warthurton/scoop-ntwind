# AI Coding Agent Instructions for `scoop-ntwind`

## Overview

This repository is a Scoop bucket for NTWind Software applications. Scoop is a Windows command-line installer, and this bucket provides JSON manifests for NTWind's utilities. The repository includes tools for validating, testing, and maintaining these manifests.

## Key Concepts

-   **Scoop Bucket**: A collection of JSON manifests defining how to install, update, and uninstall applications.
-   **Manifests**: JSON files in the `bucket/` directory that describe application metadata, download URLs, installation scripts, and more.
-   **Validation Scripts**: PowerShell scripts in the `bin/` directory for ensuring manifest correctness.

## Repository Structure

-   `bucket/`: Contains JSON manifests for NTWind applications.
-   `bin/`: PowerShell scripts for validation and automation.
-   `deprecated/`: Deprecated manifests.
-   `scripts/`: Additional utility scripts.
-   `.github/`: GitHub Actions workflows and templates.

## Development Workflow

1. **Create a Manifest**:
    - Copy `bucket/app-name.json.template` to `bucket/<app-name>.json`.
    - Fill in the fields with application details.
2. **Validate the Manifest**:
    - Run `pwsh bin/checkver.ps1` to check for version updates.
    - Run `pwsh bin/checkhashes.ps1` to verify file hashes.
    - Run `pwsh bin/checkurls.ps1` to validate URLs.
    - Format the JSON with `pwsh bin/formatjson.ps1`.
3. **Test the Manifest**:
    - Run `pwsh bin/test.ps1` to execute all tests.
    - Run `pwsh Scoop-Bucket.Tests.ps1` for bucket-specific tests.
4. **Submit Changes**:
    - Use `pwsh bin/auto-pr.ps1` to create a pull request for updates.

## Key Commands

-   `pwsh bin/test.ps1`: Run all tests using the Pester framework.
-   `pwsh bin/checkver.ps1`: Check for version updates.
-   `pwsh bin/checkhashes.ps1`: Verify file hashes.
-   `pwsh bin/checkurls.ps1`: Validate URLs.
-   `pwsh bin/formatjson.ps1`: Format JSON manifests.
-   `pwsh bin/auto-pr.ps1`: Create automatic pull requests.

## Project-Specific Conventions

-   **JSON Formatting**: Use `pwsh bin/formatjson.ps1` to ensure consistent formatting.
-   **Validation**: Always validate manifests before submitting.
-   **Testing**: Use Pester for testing. Ensure PowerShell 5.1+ and required modules (`Pester`, `BuildHelpers`) are installed.

## GitHub Actions

-   **CI Workflow**: `.github/workflows/ci.yml` runs tests on pull requests and pushes.
-   **Excavator Workflow**: `.github/workflows/excavator.yml` automates daily updates.
-   **Pull Request Workflow**: `.github/workflows/pull_request.yml` handles PR events.

## External Dependencies

-   **Scoop**: Required for testing manifests.
-   **PowerShell Modules**: `Pester` (5.2.0+), `BuildHelpers` (2.0.1+).

## Examples

-   **Manifest Template**: `bucket/app-name.json.template` provides a starting point for new manifests.
-   **Validation Script**: `bin/checkver.ps1` checks for version updates across all manifests.

## Notes

-   Follow the [Contributing Guide](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md) for submitting changes.
-   Use the `.editorconfig` file to maintain consistent coding styles.

---

For additional questions, refer to the [README.md](../README.md) or the [CLAUDE.md](../CLAUDE.md) file.
