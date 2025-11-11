# AI Coding Agent Instructions for `scoop-ntwind`

## Overview

This repository is a Scoop bucket for NTWind Software applications. Scoop is a Windows command-line installer, and this bucket provides JSON manifests for NTWind's utilities. The repository includes tools for validating, testing, and maintaining these manifests.

## Key Guidelines

1. **PowerShell Compatibility**: Ensure scripts work with both PowerShell 5.1 and the latest versions. Use backward-compatible syntax.
2. **Scoop Standards**: Follow [Scoop-00File.Tests.ps1](https://github.com/ScoopInstaller/Scoop/blob/master/test/Scoop-00File.Tests.ps1) for validation and best practices.
3. **Testing**: Use Pester for tests. Ensure required modules (`Pester`, `BuildHelpers`) are installed.
4. **JSON Formatting**: Use `bin/formatjson.ps1` to maintain consistent formatting.

## Development Workflow

1. Create or update manifests in the `bucket/` directory.
2. Validate manifests using scripts in `bin/`.
3. Test changes with `bin/test.ps1`.
4. Submit changes via pull requests.

For additional details, refer to the [README.md](../README.md) or the [Contributing Guide](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md).
