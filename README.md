# EnvSwitch

A macOS tool for managing multiple local environment-variable profiles and switching between them with one click — like [SwitchHosts](https://github.com/oldj/SwitchHosts), but for environment variables. Ships with both a **CLI** (`envswitch`) and a **GUI** (menu-bar quick switch + main editor window).

Configuration lives under your home directory at `~/.config/envswitch/` — never inside project folders.

## Features

- Multiple environment profiles plus a shared **base** layer; switch with one click.
- **GUI** (menu-bar quick switch + editor window) and **CLI** (`envswitch`) that share one core.
- Single TOML config under `~/.config/envswitch/` — nothing in your project folders.
- New terminals auto-load the active environment via a zsh hook; apply to an already-open shell with one command.
- Optional **launchctl sync** so GUI apps launched afterward see the variables.
- Plain-text values, **zsh**, **macOS 14+**.

## Quick start

1. **Install** — open `dist/EnvSwitch-0.1.0.dmg`, drag **EnvSwitch.app** to *Applications* (first launch: right-click → **Open**). Or build from source (see [Install](#install)).
2. **Add variables** — open EnvSwitch, pick `base` or create an environment, add `KEY` / value at the bottom. Click **Activate** to make an environment current (variables in `base` apply even without activating).
3. **Wire up your shell** — accept the first-run prompt to install the zsh hook (or run `envswitch shell-init >> ~/.zshrc`).
4. **Use it** — open a new terminal and your variables are loaded. For a terminal that is already open, run `eval "$(envswitch export)"`.

## How activation works (read this first)

On macOS, environment variables are inherited by a process **when it starts** from its parent. Unlike `/etc/hosts` (which is read live on every lookup), there is no way to globally change variables for already-running processes. EnvSwitch therefore activates an environment like this:

1. When you switch (or edit) environments, EnvSwitch merges `base` + the active environment and writes the result to `~/.config/envswitch/active.env` (a file of `export KEY='VALUE'` lines, mode `600`). Editing the active environment or base regenerates this file immediately.
2. A one-line hook in your `~/.zshrc` sources that file, so **every new terminal automatically loads the active environment**.
3. For a terminal that is **already open**, run `eval "$(envswitch export)"` to apply the active environment to that shell. (`envswitch reload` only regenerates `active.env`; it cannot change a process that is already running.)
4. Optionally, enable **launchctl sync** so that GUI apps launched afterward (from Dock/Spotlight) also see the variables (`launchctl setenv`). This is off by default and requires restarting the target app.

If no environment is activated, the **base layer alone** is still exported — so variables you only need everywhere can live in `base`.

Only **zsh** is supported.

## Data model

A single TOML file at `~/.config/envswitch/config.toml` with a shared `base` layer plus per-environment overrides. The active environment's effective variables are `base` merged with the environment (environment keys win).

```toml
active = "dev"                 # currently active environment
launchctl_sync = false         # sync to GUI apps via launchctl setenv

[base]                         # always applied
LANG = "zh_CN.UTF-8"
EDITOR = "vim"

[env.dev]
API_HOST = "dev.example.com"
TOKEN = "dev-token"

[env.prod]
API_HOST = "prod.example.com"
TOKEN = "prod-token"
```

All values are stored as plain text in `config.toml`, and the generated `active.env` (mode `600`) holds the resolved values the shell sources. Because environment variables are inherently plain text once exported, EnvSwitch does not attempt to encrypt them; keep secrets out of any synced/committed copy of `config.toml` if that matters to you.

## Install

### From the prebuilt app (.dmg)

1. Open `dist/EnvSwitch-0.1.0.dmg` and drag **EnvSwitch.app** to *Applications*.
2. First launch only: because the app is ad-hoc signed (not notarized), right-click it → **Open**, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/EnvSwitch.app
   ```
3. On first launch the app offers to install the zsh hook and shows the command to put the CLI on your PATH. The embedded CLI lives at `/Applications/EnvSwitch.app/Contents/Resources/envswitch`; link it without sudo:
   ```bash
   mkdir -p ~/.local/bin && ln -sf "/Applications/EnvSwitch.app/Contents/Resources/envswitch" ~/.local/bin/envswitch
   ```
   (Make sure `~/.local/bin` is on your `PATH`, then open a new terminal.)

### From source

Requires Swift 5.9+ / macOS 14+.

```bash
git clone <this-repo> && cd envswitch
swift build -c release

# Put the CLI on your PATH (no sudo needed):
mkdir -p ~/.local/bin && ln -sf "$(pwd)/.build/release/envswitch" ~/.local/bin/envswitch

# Install the zsh hook (or paste the output into ~/.zshrc yourself):
envswitch shell-init >> ~/.zshrc
exec zsh   # reload your shell
```

## CLI reference

```
envswitch list                 # list environments, marking the active one with *
envswitch use <env>            # switch active environment (new shells pick it up)
envswitch reload               # regenerate active.env from base + the active environment
envswitch current              # show the active environment and its exports
envswitch get KEY              # print a resolved variable value
envswitch set <env> KEY VALUE  # set a variable (use "base" as <env> for the base layer)
envswitch unset <env> KEY      # remove a variable
envswitch add <env>            # create an environment
envswitch rm <env>             # delete an environment
envswitch edit                 # open config.toml in $EDITOR
envswitch export [<env>]       # print export statements for eval
envswitch import <env> <.env>  # import KEY=VALUE lines from a .env file
envswitch shell-init           # print the zsh hook to add to ~/.zshrc
```

### Typical use in an open shell

```bash
envswitch use dev      # switch globally (affects new shells)
eval "$(envswitch export)"   # apply to THIS shell right now
```

## GUI

- **Menu bar** (`switch.2` icon): the list of environments with a filled dot on the active one — click to switch instantly. Also offers *Edit Environments…* and *How to use…* (both open the main window).
- **Main window**: a sidebar with `base` + your environments, and a table of the selected layer's variables. Add variables with the KEY / value fields at the bottom; **double-click** (or right-click → Copy, or the copy icon) to copy a key or value; the trash icon deletes a variable.
  - **Activate** sets the selected environment as active; **Reload** regenerates `active.env` on demand. A footer shows the `eval "$(envswitch export)"` command (with a copy button) for already-open terminals.
  - The **?** button opens an in-app, Chinese usage guide covering activation, applying to a terminal, and installing the CLI.
- **Settings**: toggle launchctl sync.
- On first launch a setup sheet offers to install the zsh hook and shows the CLI symlink command.

## Architecture

A SwiftPM workspace with three pieces sharing one core library:

- **EnvSwitchCore** — TOML config read/write (atomic), `base + env` merge, `active.env` generation with shell escaping, the zsh hook snippet, and `launchctl` sync. All behavior is unit-tested.
- **envswitch** — the CLI (swift-argument-parser), a thin wrapper over Core.
- **EnvSwitchGUI** — SwiftUI app: `MenuBarExtra` for quick switching, a main window with the environment list and variable editor, and a settings pane.

Tests live in `Tests/EnvSwitchCoreTests` and run with `swift test`. (This project standardizes on the **Swift Testing** framework rather than XCTest.)

For environment isolation, the CLI honors `ENVSWITCH_HOME` to point at an alternate config root (used by tests and for trying things out safely).

## Packaging an installable app

Run the bundled script — it builds release binaries, assembles a signed `.app`, and produces a `.dmg`:

```bash
scripts/package.sh
# Produces:
#   dist/EnvSwitch.app
#   dist/EnvSwitch-0.1.0.dmg
```

The script ad-hoc code-signs the bundle (no Apple Developer account needed). The GUI is the bundle's main executable (`Contents/MacOS/EnvSwitch`), and the `envswitch` CLI is embedded at `Contents/Resources/envswitch` (kept out of `MacOS/` because macOS volumes are case-insensitive and `EnvSwitch`/`envswitch` would otherwise collide). On first launch the app offers to install the zsh hook and shows the command to symlink the embedded CLI onto your PATH.

> Because the app is ad-hoc signed (not notarized), the first launch needs a right-click → **Open** (or `xattr -dr com.apple.quarantine EnvSwitch.app`) to get past Gatekeeper. For wider distribution, sign with a Developer ID and notarize.

## Design docs

- Spec: `docs/superpowers/specs/2026-06-01-envswitch-design.md`
- Implementation plan: `docs/superpowers/plans/2026-06-01-envswitch.md`
