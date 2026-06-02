# Hoist

A macOS utility that automatically raises and focuses windows on mouse hover. Optionally warps the mouse to the center of the activated window when using Cmd-Tab.

## Quick Start

### Install via Homebrew (recommended)

```bash
brew install aaabramov/hoist/hoist
```

### Install via script

```bash
curl -fsSL https://raw.githubusercontent.com/aaabramov/Hoist/master/install.sh | bash
```

### Install manually

1. Download `Hoist.dmg` from the [latest release](https://github.com/aaabramov/Hoist/releases/latest).
2. Open the DMG and drag **Hoist.app** into Applications.
3. Remove the quarantine attribute:
   ```bash
   xattr -cr /Applications/Hoist.app
   ```
4. Open Hoist from Applications.
5. **Left-click** the menu bar icon to grant Accessibility permissions.
6. **Right-click** the menu bar icon to set preferences.

> **Note:** If you see an older Hoist item in System Preferences > Accessibility, remove it completely (click minus), then restart Hoist by left-clicking the menu bar icon. Re-enable Accessibility when the new item appears.

## Using Hoist.app

- **Left-click** the menu bar icon to toggle Hoist on/off.
- **Right-click** to open the context menu for quick settings.
- Select **Preferences...** to fine-tune all parameters with sliders and text fields.

Changes are saved automatically to `~/.config/hoist/config.json`.

## Configuration

Hoist can be configured via the preferences UI, a JSON config file, or command line arguments. Config file values are loaded first; CLI arguments override them.

### Config file

Location: `~/.config/hoist/config.json`

```json
{
    "pollMillis": 50,
    "delay": 1,
    "focusDelay": 0,
    "warpX": 0.5,
    "warpY": 0.1,
    "scale": 2.5,
    "scaleDuration": 600,
    "altTaskSwitcher": false,
    "requireMouseStop": true,
    "ignoreSpaceChanged": false,
    "invertDisableKey": false,
    "invertIgnoreApps": false,
    "ignoreApps": ["IntelliJ IDEA", "WebStorm"],
    "ignoreTitles": ["\\s\\| Microsoft Teams", "^window$"],
    "stayFocusedBundleIds": ["com.apple.SecurityAgent"],
    "disableKey": "control",
    "mouseDelta": 0.1
}
```

### Command line usage

```bash
./Hoist \
  -pollMillis 50 \
  -delay 1 \
  -warpX 0.5 \
  -warpY 0.1 \
  -scale 2.5 \
  -scaleDuration 600 \
  -altTaskSwitcher false \
  -requireMouseStop false \
  -ignoreSpaceChanged false \
  -ignoreApps "App1,App2" \
  -ignoreTitles "^window$" \
  -stayFocusedBundleIds "Id1,Id2" \
  -disableKey control \
  -mouseDelta 0.1
```

### Configuration properties

#### Timing

| Property | Default | Description |
|----------|---------|-------------|
| `pollMillis` | `50` | How often (ms) to poll the mouse position. Lower = more responsive but higher CPU. Minimum: 20. |
| `delay` | `1` | Raise delay in units of `pollMillis`. `0` = disabled, `1` = no delay, `>1` = requires mouse stop. |
| `focusDelay` | `0` | Focus delay in units of `pollMillis`. Same behavior as `delay`. *Requires `EXPERIMENTAL_FOCUS_FIRST` flag.* |

#### Mouse Warp & Cursor

| Property | Default | Description |
|----------|---------|-------------|
| `warpX` | `0` (disabled) | Horizontal warp factor (0–1). Warps the mouse to the activated window. |
| `warpY` | `0` (disabled) | Vertical warp factor (0–1). Warps the mouse to the activated window. |
| `scale` | `2.0` | Cursor enlargement after warping. Set to `1.0` to disable. |
| `scaleDuration` | `600` | How long (ms) the enlarged cursor is shown after warping. Minimum: 200. |
| `mouseDelta` | `0.0` | Minimum mouse movement distance required. `0.0` = most sensitive, higher = less sensitive. |

#### Behavior

| Property | Default | Description |
|----------|---------|-------------|
| `requireMouseStop` | `true` | Require the mouse to stop moving before raise/focus. |
| `ignoreSpaceChanged` | `false` | Do not immediately raise/focus after a space (desktop) change. |
| `altTaskSwitcher` | `false` | Set to `true` if you use a third-party task switcher (e.g., AltTab). |
| `disableWhenNoExternalScreen` | `false` | Automatically disable raise/focus when no external display is connected (e.g. laptop on its built-in screen only). Restores when an external display is reconnected. Clamshell mode (lid closed + one external monitor) stays enabled. |
| `disableKey` | `control` | Hold this key to temporarily disable Hoist. Options: `control`, `option`, `disabled`. |
| `invertDisableKey` | `false` | Inverts the disable key behavior (Hoist only active while key is held). |
| `verbose` | `false` | Log events to the terminal. |

#### App & Window Filtering

| Property | Default | Description |
|----------|---------|-------------|
| `ignoreApps` | *(empty)* | Comma-separated list of app names to exclude from focus/raise. |
| `invertIgnoreApps` | `false` | Turns `ignoreApps` into an include-only list. |
| `ignoreTitles` | *(empty)* | Comma-separated list of window titles (supports ICU regex) to exclude. |
| `stayFocusedBundleIds` | *(empty)* | Comma-separated bundle IDs of apps that should not lose focus on hover. |

## Keyboard Shortcut (AppleScript)

You can toggle Hoist with a keyboard shortcut using this AppleScript in an Automator service workflow, then bind it via System Preferences > Keyboard > Shortcuts:

```applescript
on run {input, parameters}
    tell application "Finder"
        if exists of application process "Hoist" then
            quit application "/Applications/Hoist"
            display notification "Hoist Stopped"
        else
            launch application "/Applications/Hoist"
            display notification "Hoist Started"
        end if
    end tell
    return input
end run
```

## Troubleshooting

If you experience issues, check the following:

1. Are you using the [latest version](https://github.com/aaabramov/Hoist/releases/latest)?
2. Does the command line version work? (Helps isolate GUI-specific issues.)
3. Are other mouse tools running that might interfere?
4. Are multiple Hoist instances running? Check via Activity Monitor.
5. Is Accessibility properly enabled? To reset:
   ```bash
   tccutil reset Accessibility com.iamandrii.hoist
   ```
6. Remove quarantine after download/update:
   ```bash
   xattr -cr /Applications/Hoist.app
   ```

### Verbose logging

Enable verbose output to help diagnose problems:

```bash
./Hoist -verbose true
```

If the issue persists, please [open an issue](https://github.com/aaabramov/Hoist/issues) and include a snippet of the verbose log.

## Building from Source

See [docs/building-from-source.md](docs/building-from-source.md) for compilation instructions and advanced build flags.

## Credits

This is a fork of [sbmpost/AutoRaise](https://github.com/sbmpost/AutoRaise) — huge thanks to sbmpost for creating and maintaining the original project. The menu bar status icon, preferences window, runtime configuration features, and rename to Hoist were done in this fork.
