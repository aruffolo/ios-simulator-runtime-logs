#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  start_dual_capture.sh --udid <UDID> --bundle-id <BUNDLE_ID> --allow-relaunch [--process <name> | --subsystem <value> | --predicate <expr>] [--level <debug|info|default|error|fault>] [--session-dir <path>] [--no-terminate-running-process]
EOF
}

udid=""
bundle_id=""
process_name=""
subsystem=""
predicate=""
level="debug"
session_dir=""
terminate_flag="--terminate-running-process"
allow_relaunch="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) udid="${2:-}"; shift 2 ;;
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --process) process_name="${2:-}"; shift 2 ;;
    --subsystem) subsystem="${2:-}"; shift 2 ;;
    --predicate) predicate="${2:-}"; shift 2 ;;
    --level) level="${2:-}"; shift 2 ;;
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
  echo "Refusing dual capture without --allow-relaunch; this relaunches the app and detaches Xcode." >&2
  exit 2
fi

if [[ -z "$predicate" ]]; then
  if [[ -n "$process_name" ]]; then
    predicate="process == \"$process_name\""
  elif [[ -n "$subsystem" ]]; then
    predicate="subsystem == \"$subsystem\""
  else
    echo "Provide --process, --subsystem, or --predicate" >&2
    usage
    exit 1
  fi
fi

if [[ -z "$session_dir" ]]; then
  stamp="$(date +%Y%m%d-%H%M%S)"
  session_dir=".telemetry/ios/$stamp"
fi

mkdir -p "$session_dir"
echo "$$" > "$session_dir/capture.pid"

{
  echo "mode=dual"
  echo "udid=$udid"
  echo "bundle_id=$bundle_id"
  echo "allow_relaunch=$allow_relaunch"
  echo "level=$level"
  echo "predicate=$predicate"
  echo "started_at=$(date -Iseconds)"
} > "$session_dir/metadata.txt"

echo "Session: $session_dir" >&2
echo "Bundle: $bundle_id" >&2
echo "Predicate: $predicate" >&2

xcrun simctl spawn "$udid" log stream \
  --style compact \
  --level "$level" \
  --predicate "$predicate" | tee "$session_dir/stream.log" &
log_pid=$!

cleanup() {
  kill "$log_pid" 2>/dev/null || true
  wait "$log_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

command=(xcrun simctl launch --console-pty)
if [[ -n "$terminate_flag" ]]; then
  command+=("$terminate_flag")
fi
command+=("$udid" "$bundle_id")

"${command[@]}" | tee "$session_dir/console.log"
