#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  start_log_stream.sh --udid <UDID> [--process <name> | --subsystem <value> | --predicate <expr>] [--level <debug|info|default|error|fault>] [--session-dir <path>]
EOF
}

udid=""
process_name=""
subsystem=""
predicate=""
level="debug"
session_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) udid="${2:-}"; shift 2 ;;
    --process) process_name="${2:-}"; shift 2 ;;
    --subsystem) subsystem="${2:-}"; shift 2 ;;
    --predicate) predicate="${2:-}"; shift 2 ;;
    --level) level="${2:-}"; shift 2 ;;
    --session-dir) session_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$udid" ]]; then
  echo "Missing --udid" >&2
  usage
  exit 1
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
  echo "udid=$udid"
  echo "level=$level"
  echo "predicate=$predicate"
  echo "started_at=$(date -Iseconds)"
} > "$session_dir/metadata.txt"

echo "Session: $session_dir" >&2
echo "Predicate: $predicate" >&2

xcrun simctl spawn "$udid" log stream \
  --style compact \
  --level "$level" \
  --predicate "$predicate" | tee "$session_dir/stream.log"
