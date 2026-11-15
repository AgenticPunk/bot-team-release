# Release manifests

`./release` writes `v<version>.json` here for every staged release. The manifest
records the version, build date, platform, architecture, source commit, and the
name, size, and SHA-256 of each artifact.

Binaries live in GitHub Releases, not in git. `latest.json` at the repository
root points at the newest full release and is uploaded as a release asset as
well, so installers can resolve the latest version without the GitHub API.
