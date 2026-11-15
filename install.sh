#!/usr/bin/env bash
# Install bot-team (CLI + desktop app) from GitHub Releases.
#
# The binaries are published from a private source tree; no source code is
# downloaded or installed.
set -euo pipefail

DEFAULT_REPO="AgenticPunk/bot-team-release"
REPO="${BOT_TEAM_REPO:-$DEFAULT_REPO}"
VERSION="${BOT_TEAM_VERSION:-}"
PREFIX="${BOT_TEAM_PREFIX:-$HOME/.local}"
APPS="${BOT_TEAM_APPS:-}"
WITH_CLI=1
WITH_APP=1
TMP=""

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --version <x.y.z>   Install a specific version (default: latest release)
  --repo <owner/repo> GitHub release repository (default: AgenticPunk/bot-team-release)
  --prefix <dir>      CLI install prefix (default: ~/.local)
  --apps <dir>        App install directory (default: /Applications if writable, else ~/Applications)
  --cli-only          Install only the CLI
  --app-only          Install only the desktop app
  -h, --help          Show this help

Environment:
  BOT_TEAM_REPO       Override the GitHub release repository
  BOT_TEAM_VERSION    Override the version
  BOT_TEAM_PREFIX     Override the CLI install prefix
  BOT_TEAM_APPS       Override the app install directory
  BOT_TEAM_RELEASE_BASE
                      Override the release download base (default:
                      https://github.com/<repo>/releases); useful for mirrors/tests
EOF
}

die() {
  printf 'install: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$TMP" ] && [ -d "$TMP" ]; then
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

fetch() {
  curl -fsSL --retry 3 --connect-timeout 15 "$1" -o "$2"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      [ $# -ge 2 ] || die "--version needs a value"
      VERSION="$2"
      shift 2
      ;;
    --repo)
      [ $# -ge 2 ] || die "--repo needs a value"
      REPO="$2"
      shift 2
      ;;
    --prefix)
      [ $# -ge 2 ] || die "--prefix needs a value"
      PREFIX="$2"
      shift 2
      ;;
    --apps)
      [ $# -ge 2 ] || die "--apps needs a value"
      APPS="$2"
      shift 2
      ;;
    --cli-only)
      WITH_APP=0
      shift
      ;;
    --app-only)
      WITH_CLI=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "bot-team currently ships macOS builds only"

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64) ARCH="x86_64" ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

[ -n "$REPO" ] || die "empty repository"
BASE="${BOT_TEAM_RELEASE_BASE:-https://github.com/$REPO/releases}"
BASE="${BASE%/}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/bot-team-install.XXXXXX")"

if [ -z "$VERSION" ]; then
  META="$TMP/latest.json"
  if ! fetch "$BASE/latest/download/latest.json" "$META"; then
    die "no published release found at $BASE/latest/download/latest.json
Publish one first from the release repository: ./release --version <x.y.z> --publish"
  fi
  VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$META" | head -n 1)"
  [ -n "$VERSION" ] || die "could not read the version from $META"
fi
VERSION="${VERSION#v}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]] ||
  die "invalid version: $VERSION"

DL="$BASE/download/v$VERSION"
CLI_ASSET="bot-team-cli-${VERSION}-darwin-${ARCH}.tar.gz"
APP_ASSET="bot-team-app-${VERSION}-darwin-${ARCH}.zip"

printf '==> bot-team %s (%s)\n' "$VERSION" "$ARCH"

fetch "$DL/SHA256SUMS" "$TMP/SHA256SUMS" ||
  die "could not download $DL/SHA256SUMS"

verify_asset() {
  local asset="$1" expected actual
  expected="$(awk -v n="$asset" '$2 == n { print $1 }' "$TMP/SHA256SUMS" | head -n 1)"
  [ -n "$expected" ] || die "no checksum for $asset in SHA256SUMS"
  actual="$(shasum -a 256 "$TMP/$asset" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || die "checksum mismatch for $asset"
}

install_cli() {
  local asset="$1" extract="$TMP/cli-extract" top=""
  fetch "$DL/$asset" "$TMP/$asset" || die "could not download $DL/$asset"
  verify_asset "$asset"

  mkdir -p "$extract"
  tar -xzf "$TMP/$asset" -C "$extract"
  top="$(find "$extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -n "$top" ] && [ -x "$top/bin/bot-team" ] || die "invalid CLI archive"

  mkdir -p "$PREFIX"
  PREFIX="$(cd "$PREFIX" && pwd)"
  mkdir -p "$PREFIX/share/bot-team" "$PREFIX/bin"
  rm -rf "$PREFIX/share/bot-team/cli"
  mv "$top" "$PREFIX/share/bot-team/cli"
  chmod 755 "$PREFIX/share/bot-team/cli/bin/bot-team" \
    "$PREFIX/share/bot-team/cli/bin/btpty"
  # The upstream launcher resolves its root from $0, so a symlink into bin/
  # would make it look one directory too high. Use a tiny absolute wrapper.
  {
    printf '#!/bin/sh\n'
    printf 'exec "%s/bin/bot-team" "$@"\n' "$PREFIX/share/bot-team/cli"
  } > "$PREFIX/bin/bot-team"
  chmod 755 "$PREFIX/bin/bot-team"

  printf '  cli: %s/bin/bot-team\n' "$PREFIX"
  case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) printf '  add to PATH: export PATH="%s/bin:$PATH"\n' "$PREFIX" ;;
  esac

  local node_bin="${BOT_TEAM_NODE:-node}" major="0"
  if ! command -v "$node_bin" >/dev/null 2>&1; then
    printf '  warning: node was not found; the CLI needs Node.js 20+\n'
  else
    major="$("$node_bin" -p 'process.versions.node.split(".")[0]' 2>/dev/null || printf '0')"
    if [ "$major" -lt 20 ] 2>/dev/null; then
      printf '  warning: Node.js %s found; bot-team needs Node.js 20+\n' "$major"
    fi
  fi
}

install_app() {
  local asset="$1" extract="$TMP/app-extract"
  fetch "$DL/$asset" "$TMP/$asset" || die "could not download $DL/$asset"
  verify_asset "$asset"

  mkdir -p "$extract"
  ditto -x -k "$TMP/$asset" "$extract"
  [ -d "$extract/bot-team.app" ] || die "invalid app archive"

  # The app is ad-hoc signed, not notarized. Clear the download quarantine so
  # Gatekeeper's first launch does not reject it.
  xattr -dr com.apple.quarantine "$extract/bot-team.app" 2>/dev/null || true

  if [ -z "$APPS" ]; then
    if [ -w /Applications ]; then
      APPS="/Applications"
    else
      APPS="$HOME/Applications"
    fi
  fi
  mkdir -p "$APPS"
  APPS="$(cd "$APPS" && pwd)"
  rm -rf "$APPS/bot-team.app"
  mv "$extract/bot-team.app" "$APPS/bot-team.app"
  printf '  app: %s/bot-team.app\n' "$APPS"
}

if [ "$WITH_CLI" -eq 1 ]; then
  install_cli "$CLI_ASSET"
fi
if [ "$WITH_APP" -eq 1 ]; then
  install_app "$APP_ASSET"
fi

printf '\nInstalled bot-team %s.\n' "$VERSION"
if [ "$WITH_CLI" -eq 1 ]; then
  printf 'Try: bot-team help\n'
fi
if [ "$WITH_APP" -eq 1 ]; then
  printf 'Open: open "%s/bot-team.app"\n' "$APPS"
fi
