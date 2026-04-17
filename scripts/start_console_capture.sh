#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  start_console_capture.sh --udid <UDID> --bundle-id <BUNDLE_ID> --allow-relaunch [--session-dir <path>] [--no-terminate-running-process]
EOF
}

udid=""
bundle_id=""
session_dir=""
terminate_flag="--terminate-running-process"
allow_relaunch="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) udid="${2:-}"; shift 2 ;;
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --session-dir) session_dir="${2:-}"; shift 2 ;;
    --no-terminate-running-process) terminate_flag=""; shift 1 ;;
    --allow-relaunch) allow_relaunch="1"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$udid" || -z "$bundle_id" ]]; then
  echo "Missing --udid or --bundle-id" >&2
  usage
  exit 1
fi

if [[ "$allow_relaunch" != "1" ]]; then
  echo "Refusing console capture without --allow-relaunch; this relaunches the app and detaches Xcode." >&2
  exit 2
fi

if [[ -z "$session_dir" ]]; then
  stamp="$(date +%Y%m%d-%H%M%S)"
  session_dir=".telemetry/ios/$stamp"
fi

mkdir -p "$session_dir"
echo "$$" > "$session_dir/capture.pid"

{
  echo "mode=console"
  echo "udid=$udid"
  echo "bundle_id=$bundle_id"
  echo "allow_relaunch=$allow_relaunch"
  echo "started_at=$(date -Iseconds)"
} > "$session_dir/metadata.txt"

echo "Session: $session_dir" >&2
echo "Bundle: $bundle_id" >&2

command=(xcrun simctl launch --console-pty)
if [[ -n "$terminate_flag" ]]; then
  command+=("$terminate_flag")
fi
command+=("$udid" "$bundle_id")

"${command[@]}" | tee "$session_dir/console.log"
