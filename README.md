# iOS Simulator Runtime Logs

Console-first Codex skill for iOS Simulator runtime debugging.

Primary value:
- capture the same `print` / `debugPrint` lines usually read in Xcode
- optionally capture unified logs via `log stream`
- optionally do both in one saved session
- optionally build/install an Xcode app before capture

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

