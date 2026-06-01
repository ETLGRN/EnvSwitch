# EnvSwitch

A macOS tool for managing multiple local environment-variable profiles and switching between them with one click — like [SwitchHosts](https://github.com/oldj/SwitchHosts), but for environment variables. Ships with both a **CLI** (`envswitch`) and a **GUI** (menu-bar quick switch + main editor window).

Configuration lives under your home directory at `~/.config/envswitch/` — never inside project folders.

## How activation works (read this first)

On macOS, environment variables are inherited by a process **when it starts** from its parent. Unlike `/etc/hosts` (which is read live on every lookup), there is no way to globally change variables for already-running processes. EnvSwitch therefore activates an environment like this:

1. When you switch environments, EnvSwitch merges `base` + the chosen environment and writes the result to `~/.config/envswitch/active.env` (a file of `export KEY='VALUE'` lines, mode `600`).
2. A one-line hook in your `~/.zshrc` sources that file, so **every new terminal automatically loads the active environment**.
3. For terminals that are already open, run `envswitch reload` (or `eval "$(envswitch export)"`) to refresh them.
4. Optionally, enable **launchctl sync** so that GUI apps launched afterward (from Dock/Spotlight) also see the variables (`launchctl setenv`). This is off by default and requires restarting the target app.

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
TOKEN = { secret = true }      # value stored in the macOS Keychain, not here

[env.prod]
API_HOST = "prod.example.com"
TOKEN = { secret = true }
```

### Secrets

Variables marked `{ secret = true }` keep their real value in the **macOS Keychain** (service `envswitch`, account `<env>/<KEY>`; the base layer uses `base/<KEY>`). The TOML file only records the marker, and the generated `active.env` (mode `600`) is where resolved secret values are written for the shell to source.

## Installation (from source)

Requires Swift 5.9+ / macOS 14+.

```bash
git clone <this-repo> && cd envswitch
swift build -c release

# Put the CLI on your PATH:
sudo ln -sf "$(pwd)/.build/release/envswitch" /usr/local/bin/envswitch

# Install the zsh hook (or paste the output into ~/.zshrc yourself):
envswitch shell-init >> ~/.zshrc
exec zsh   # reload your shell
```

When packaged as a `.app`, the GUI embeds the `envswitch` binary and, on first run, offers to install the zsh hook and shows the symlink command for putting the CLI on your PATH.

## CLI reference

```
envswitch list                 # list environments, marking the active one with *
envswitch use <env>            # switch active environment (new shells pick it up)
envswitch reload               # refresh the current shell's active.env
envswitch current              # show the active environment and its exports
envswitch get KEY              # print a resolved variable value
envswitch set <env> KEY VALUE  # set a variable (use "base" as <env> for the base layer)
envswitch set <env> KEY --secret   # store the value in the Keychain (prompts if VALUE omitted)
envswitch unset <env> KEY      # remove a variable
envswitch add <env>            # create an environment
envswitch rm <env>             # delete an environment (and its secrets)
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

## Architecture

A SwiftPM workspace with three pieces sharing one core library:

- **EnvSwitchCore** — TOML config read/write (atomic), `base + env` merge, Keychain access, `active.env` generation with shell escaping, the zsh hook snippet, and `launchctl` sync. All behavior is unit-tested.
- **envswitch** — the CLI (swift-argument-parser), a thin wrapper over Core.
- **EnvSwitchGUI** — SwiftUI app: `MenuBarExtra` for quick switching, a main window with the environment list and variable editor, and a settings pane.

Tests live in `Tests/EnvSwitchCoreTests` and run with `swift test`. (This project standardizes on the **Swift Testing** framework rather than XCTest.)

For environment isolation, the CLI honors `ENVSWITCH_HOME` to point at an alternate config root (used by tests and for trying things out safely).

## Packaging the .app (notes)

`swift run EnvSwitchGUI` is fine for development. To ship a real double-clickable `.app` with a working menu-bar item, wrap the `EnvSwitchGUI` target in a thin Xcode project (or a tool such as `swift-bundler`): set the `Info.plist` (`LSUIElement`, bundle id), embed the release `envswitch` binary under `Contents/MacOS/`, and code-sign. This packaging step is intentionally left out of the core build.

## Design docs

- Spec: `docs/superpowers/specs/2026-06-01-envswitch-design.md`
- Implementation plan: `docs/superpowers/plans/2026-06-01-envswitch.md`
