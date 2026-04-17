# iOS Simulator Runtime Logs

Console-first Codex skill for iOS Simulator runtime debugging.

Why this exists:
- most iOS logging helpers stop at unified logs
- many runtime bugs are only visible in `print` / `debugPrint`
- simulator debugging usually also needs Xcode project resolution, build, install, and relaunch discipline
- multi-flavor apps need safe scheme handling, not guesses

Primary value:
- capture the same `print` / `debugPrint` lines usually read in Xcode
- optionally capture unified logs via `log stream`
- optionally do both in one saved session
- optionally build/install an Xcode app before capture
- ask for the scheme when multiple app flavors exist
- save reproducible log sessions with stop/summary helpers

## Differentiators

| Capability | This skill |
| --- | --- |
| Xcode-like console capture | Yes |
| Unified logs (`log stream`) | Yes |
| Dual console + unified mode | Yes |
| Build/install Xcode app before capture | Yes |
| Scheme ambiguity handled safely | Yes |
| Saved session artifacts | Yes |
| Stop helper | Yes |
| Session summary helper | Yes |

## Console vs unified

- `console`
  - default value path
  - captures `print` / `debugPrint`
  - closest to what developers read in Xcode
- `unified`
  - for `Logger` / `OSLog`
  - no relaunch
- `dual`
  - when both channels matter
  - explicit relaunch required

Skill entry:
- `ios-simulator-runtime-logs`

Main modes:
- console
- unified
- dual

Key scripts:
- `scripts/start_runtime_logs.sh`
- `scripts/build_install_xcode_app.sh`
- `scripts/stop_capture.sh`
- `scripts/summarize_session.py`

Examples:

```bash
bash scripts/start_runtime_logs.sh \
  --udid <SIMULATOR_UDID> \
  --bundle-id com.example.app \
  --allow-relaunch
```

```bash
bash scripts/start_runtime_logs.sh \
  --udid <SIMULATOR_UDID> \
  --unified \
  --process AppName
```

```bash
bash scripts/start_runtime_logs.sh \
  --udid <SIMULATOR_UDID> \
  --build-xcode \
  --allow-relaunch
```

Behavior:
- console/dual relaunch the app; explicit `--allow-relaunch` required
- unified mode does not relaunch
- when multiple app-like schemes are found, the skill asks which scheme to use

## Why it is stronger than a plain log wrapper

- console-first, not `log stream`-first
- Xcode project aware
- simulator-aware target resolution
- scheme-safe on complex repos
- reproducible saved sessions instead of ad hoc terminal output
