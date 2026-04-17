#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  stop_capture.sh --session-dir <path>
EOF
}

session_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) session_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$session_dir" ]]; then
  echo "Missing --session-dir" >&2
  usage
  exit 1
fi

pid_file="$session_dir/capture.pid"
if [[ ! -f "$pid_file" ]]; then
  echo "No capture.pid in $session_dir" >&2
  exit 1
fi

pid="$(cat "$pid_file")"
if kill "$pid" 2>/dev/null; then
  echo "Stopped capture pid $pid"
else
  echo "Process $pid not running"
fi
