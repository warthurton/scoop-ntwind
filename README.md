# NTWind Software Scoop Bucket

Scoop bucket for [NTWind Software](https://www.ntwind.com/) applications. This bucket provides easy installation of NTWind's Windows utilities through [Scoop](https://scoop.sh), the Windows command-line installer.

A complete list of all NTWind software downloads is available at https://www.ntwind.com/download-all.html

## Monitoring for New Applications

This repository includes an automated weekly check for new NTWind applications on the [download page](https://www.ntwind.com/download-all.html). When new applications are detected, GitHub issues are automatically created to track adding them to the bucket. Check the [Issues tab](../../issues) to see applications that need manifests.

## How do I install NTWind software?

To install NTWind software using this bucket:

```pwsh
scoop bucket add ntwind https://github.com/warthurton/scoop-ntwind
scoop install ntwind/<app-name>
```

For example, to install a specific NTWind application:
```pwsh
scoop install ntwind/some-ntwind-app
```

## How do I contribute new manifests?

To make a new manifest contribution, please read the [Contributing
Guide](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md)
and [App Manifests](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
wiki page.
