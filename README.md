# bot-team releases

Prebuilt **bot-team** binaries: a zero-dependency headless agent-team core/CLI
and an Electron desktop app. This repository distributes compiled artifacts
only — no TypeScript source or source maps.

- **CLI** — `bot-team` (headless core, team protocol, issues, activity journal)
- **Desktop app** — `bot-team.app` for macOS (Apple Silicon and Intel when built)

Binaries are attached to [GitHub Releases](../../releases). Nothing large is
committed to git, so clones stay small and each release can be downloaded on
its own.

## Requirements

- macOS on the matching architecture (`arm64` or `x86_64`)
- **CLI:** Node.js 20 or newer on `PATH` (or set `BOT_TEAM_NODE`)
- **App:** no separate Node.js install; the app runs its bundled core
- Agent harnesses (`omp`, `claude`, `codex`, `antigravity`, `pi`) are separate
  tools and are not bundled. Install and authenticate the ones you use.

## Install

From a checkout of this repository:

```sh
./install.sh
```

Or directly from GitHub:

```sh
curl -fsSL https://raw.githubusercontent.com/AgenticPunk/bot-team-release/main/install.sh | bash
```

The installer downloads the latest release, verifies `SHA256SUMS`, installs the
CLI under `~/.local/share/bot-team/cli` with a `~/.local/bin/bot-team`
launcher, and installs the app to `/Applications` (or `~/Applications` when not
writable).

Options:

```sh
./install.sh --cli-only                 # CLI only
./install.sh --app-only                 # app only
./install.sh --version 0.2.0            # pin a release
./install.sh --prefix "$HOME/.local"    # CLI prefix
./install.sh --apps "$HOME/Applications"
```

If `~/.local/bin` is not on `PATH`, add it:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

You can also download the `.tar.gz` / `.zip` assets manually from the
[releases page](../../releases).

## Quick start

```sh
bot-team version
bot-team help

# optional terminal core; the app starts one automatically when needed
bot-team serve

# drive a team
bot-team spawn lead --harness omp --cwd ~/some/repo
bot-team spawn worker --harness claude --cwd ~/some/repo
bot-team send lead "Greet worker: bot-team send worker \"hello\""
bot-team ls
bot-team read lead --lines 80

# desktop app
open /Applications/bot-team.app
```

State lives in `~/.local/state/bot-team`. Set `BOT_TEAM_HOME` to isolate a
team; `BOT_TEAM_GLOBAL` isolates the team journal.

## Updating

Rerun the installer. It replaces the CLI directory and `bot-team.app` in place.

## Uninstall

```sh
rm -rf "$HOME/.local/share/bot-team" "$HOME/.local/bin/bot-team"
rm -rf /Applications/bot-team.app   # or ~/Applications/bot-team.app
# optional: rm -rf ~/.local/state/bot-team ~/.bot-team
```

## Troubleshooting

**App is blocked by Gatekeeper.** The build is ad-hoc signed, not notarized.
The installer clears the quarantine attribute; if you unzipped it manually:

```sh
xattr -dr com.apple.quarantine /Applications/bot-team.app
```

**`bot-team: node not found`.** Install Node.js 20+ or point the launcher at a
node binary:

```sh
export BOT_TEAM_NODE="$HOME/.nvm/versions/node/v22.0.0/bin/node"
```

**A harness is missing.** bot-team coordinates other agent CLIs; install the
harness you selected and make sure its binary is on `PATH` (or set
`BOT_TEAM_OMP_BIN`, `BOT_TEAM_CLAUDE_BIN`, `BOT_TEAM_CODEX_BIN`,
`BOT_TEAM_ANTIGRAVITY_BIN`, `BOT_TEAM_PI_BIN`).

## Maintaining this repository

The private source tree is expected at `../bot-team` (override with
`BOT_TEAM_SRC` or `--source`). Build tooling is required there: `pnpm`, Node.js,
and a C compiler for `btpty`.

```sh
./release                              # build CLI + app, stage ./dist, no network
./release --no-build                   # stage the existing build output
./release --version 0.3.0              # override the version
./release --only cli                   # stage only the CLI
./release --version 0.3.0 --publish    # commit metadata, push, tag, publish
```

`./release` builds the CLI with `pnpm --filter @bot-team/cli build` and packages
the app with `pnpm --filter @bot-team/app release`, then stages:

```
dist/
  bot-team-cli-<version>-darwin-<arch>.tar.gz
  bot-team-app-<version>-darwin-<arch>.zip
  SHA256SUMS
  latest.json
releases/v<version>.json     # tracked metadata
latest.json                  # tracked pointer to the newest full release
```

The CLI archive contains only `bin/`, compiled `dist/*.js`, a runtime
`package.json`, `README.txt`, and `LICENSE`. TypeScript, `.d.ts`, `.map`, and
`fake/` test fixtures are excluded.

`dist/` is intentionally **not** committed. The Electron zip is already near
GitHub's 100 MB per-file limit, so artifacts belong in GitHub Releases; the
tracked manifests are enough to audit what was published.

`--publish` requires an `origin` remote and authenticated `gh`. It commits
`latest.json` and `releases/v<version>.json` (refusing unrelated changes),
pushes the branch and `v<version>` tag, and creates or updates the GitHub
release. Release notes are generated locally, not from commit history.

To publish under another repository name, change `DEFAULT_REPO` in
`install.sh` (or pass `--repo`/`BOT_TEAM_REPO`).

## License

Proprietary. The binaries may be downloaded and used under the terms in
[LICENSE](LICENSE). No source code license is granted; source is not included.
