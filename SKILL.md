---
name: ios-simulator-runtime-logs
description: Capture iOS Simulator runtime logs with console-first defaults for `print` and `debugPrint`, plus optional unified-log and dual modes. Use when debugging runtime behavior on iOS Simulator, reading the same logs seen in Xcode, streaming `log stream` output, or saving reproducible log sessions around a repro.
---

# iOS Simulator Runtime Logs

Use this skill for simulator-first runtime logs. Default to the same runtime
channels developers usually inspect in Xcode:

- console output via `simctl launch --console-pty`
- unified logs via `log stream`
- both together when needed

Keep sessions reproducible, filtered, and saved.

It can also build and install the current Xcode project before capture.

## Core Guidelines

- Prefer existing app `Logger` / `OSLog` output over adding temporary `print`.
- Reuse current simulator context when reliable.
- Use exact UDIDs internally; only accept names as input convenience.
- Start capture before launch or repro when timing matters.
- Filter early by process, subsystem, category, or message pattern.
- Save each capture session to disk with timestamp, simulator, and predicate.
- Treat `axe` and `peekaboo` as optional helpers, not dependencies.
- Remember: `log stream` does not show all `stdout` / `stderr` lines you see in Xcode.
- Default assumption: when a user says "logs", they usually mean `print` / `debugPrint` / Xcode console.
- Preserve Xcode debugging by default. Never relaunch for console capture unless the user explicitly allows detaching the current process.

## Simulator Selection Order

1. Explicit user target.
2. Current Codex session simulator, if recent and coherent.
3. Single booted simulator.
4. Ask the user to choose when multiple or none.

Do not re-scan or ask if the session already has a trustworthy active simulator.

## Workflow

1. Resolve the simulator.
   - Use `scripts/resolve_simulator.py` with a user-provided UDID or name when needed.
   - If there is one booted simulator, use it directly.

2. Optionally resolve/build the Xcode app.
   - Use `scripts/build_install_xcode_app.sh` when the user wants a fresh local build.
   - It can auto-discover:
     - workspace or project
     - scheme
     - app target
   - Or accept explicit overrides.
   - If multiple app-like schemes are found, stop and ask the user which `--scheme` to use. Do not guess across flavors.

3. Decide the narrowest useful filter.
   - Process only:
     - `process == "AppName"`
   - Subsystem:
     - `subsystem == "com.example.app"`
   - Category:
     - `subsystem == "com.example.app" AND category == "Networking"`
   - Error-only:
     - `process == "AppName" AND (messageType == error OR messageType == fault)`
   - Message contains:
     - `process == "AppName" AND eventMessage CONTAINS[c] "token"`

4. Choose the capture mode.
   - Default:
     - `scripts/start_runtime_capture.sh`
     - defaults to Xcode-like console capture
   - Unified logs only:
     - `scripts/start_log_stream.sh`
   - Xcode-like console only:
     - `scripts/start_console_capture.sh`
   - Dual capture:
     - `scripts/start_dual_capture.sh`

5. Create a session folder.
   - Use `.telemetry/ios/<timestamp>/` in the current project when inside a repo.
   - Otherwise use a nearby temporary folder and print the path.
   - Save:
     - `metadata.txt`
     - `stream.log` for unified logs
     - `console.log` for Xcode-like console output when applicable

6. Start live capture.
   - If the user wants a fresh build/install first:
     - prefer the main wrapper with `--build-xcode`
     - use `--prepare-cmd` only for project-specific custom flows
   - If `xcodebuildmcp` tools are available in the session:
     - prefer them for project/workspace, scheme, build, install, and simulator launch discovery
     - keep the shell scripts as fallback
   - Unified logs:
     - `xcrun simctl spawn <UDID> log stream --style compact --level <level> --predicate '<predicate>'`
   - Console output:
     - `xcrun simctl launch --console-pty --terminate-running-process <UDID> <bundle-id>`
     - only when explicit relaunch is acceptable
   - Dual:
     - start `log stream` first
     - then relaunch with `--console-pty`

7. Perform the repro.
   - Launch the app or reproduce the interaction.
   - If UI interaction is needed, optionally use `axe`.
   - If visual confirmation is needed, optionally use `peekaboo`.

8. Tighten or widen.
   - If output is noisy, move from message pattern to subsystem/category or process.
   - If output is empty, broaden from category to subsystem or process.
   - If the missing lines are visible in Xcode but not in `log stream`, switch to `console` or `dual`.

9. Summarize with evidence.
   - Quote exact log lines.
   - Include:
     - simulator UDID
     - capture mode
     - predicate when applicable
     - level when applicable
     - session path

## Preferred Commands

- Resolve simulator:
  - `python3 scripts/resolve_simulator.py`
  - `python3 scripts/resolve_simulator.py "iPhone 17 Pro Max"`
  - `python3 scripts/resolve_simulator.py <UDID>`

- Start stream:
  - `bash scripts/start_log_stream.sh --udid <UDID> --process MiniAppHost`
  - `bash scripts/start_log_stream.sh --udid <UDID> --subsystem com.example.app`
  - `bash scripts/start_log_stream.sh --udid <UDID> --predicate 'process == "MiniAppHost" OR eventMessage CONTAINS[c] "token"'`

- Start with default behavior:
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --bundle-id com.example.app --allow-relaunch`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --bundle-id com.example.app --allow-relaunch --dual --process AppName`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --unified --process AppName`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --build-xcode --allow-relaunch`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --build-xcode --scheme MyApp --allow-relaunch`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --build-xcode --workspace App.xcworkspace --scheme MyApp --allow-relaunch --dual --process AppName`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --bundle-id com.example.app --allow-relaunch --prepare-cmd 'make run'`
  - `bash scripts/start_runtime_logs.sh --udid <UDID> --bundle-id com.example.app --allow-relaunch --prepare-cmd 'xcodebuild ... && xcrun simctl install ...'`

- Build/install only:
  - `bash scripts/build_install_xcode_app.sh --udid <UDID>`
  - `bash scripts/build_install_xcode_app.sh --udid <UDID> --workspace App.xcworkspace --scheme MyApp`

- Start console capture:
  - `bash scripts/start_console_capture.sh --udid <UDID> --bundle-id com.example.app --allow-relaunch`

- Start dual capture:
  - `bash scripts/start_dual_capture.sh --udid <UDID> --bundle-id com.example.app --process AppName --allow-relaunch`

- Stop a running capture:
  - `bash scripts/stop_capture.sh --session-dir .telemetry/ios/<timestamp>`

- Summarize a finished capture:
  - `python3 scripts/summarize_session.py .telemetry/ios/<timestamp>`

## Output Expectations

Provide:

- simulator chosen and why
- capture mode
- exact predicate when used
- exact command
- exact Xcode resolution/build command when used
- exact prepare command when used
- session path
- whether logs were relevant, empty, or noisy
- smallest sensible next filter adjustment

## Guardrails

- Do not describe physical-device workflows as if they apply to simulators.
- Do not use `booted` if a concrete UDID is already known.
- Do not stream the full firehose unless there is no narrower starting point.
- Do not claim a runtime event happened without quoting or referencing the log line.
- Do not detach Xcode by surprise. Console and dual capture require relaunch; require explicit user consent first.
- Do not promise console attach to an already-running app. There is no safe attach path for `stdout` / `stderr`.
- Do not require `axe` or `peekaboo`; suggest them only when they help repro.
- Do not force a generic `Debug` configuration onto repos with custom scheme configs; prefer the scheme's resolved configuration unless the user explicitly overrides it.
