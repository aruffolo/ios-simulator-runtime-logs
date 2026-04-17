#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  start_runtime_capture.sh --udid <UDID> [--bundle-id <BUNDLE_ID>] [--process <name> | --subsystem <value> | --predicate <expr>] [--session-dir <path>] [--level <debug|info|default|error|fault>] [--prepare-cmd <command>] [--build-xcode] [--workspace <path> | --project <path>] [--scheme <name>] [--configuration <name>] [--derived-data-path <path>] [--cwd <path>] [--allow-relaunch] [--dual] [--unified]

Defaults:
  - console mode by default
  - use --unified for log stream only
  - use --dual for console + unified logs
EOF
}

udid=""
bundle_id=""
process_name=""
subsystem=""
predicate=""
session_dir=""
level="debug"
prepare_cmd=""
build_xcode="0"
workspace=""
project=""
scheme=""
configuration=""
derived_data_path=""
cwd="."
allow_relaunch="0"
mode="console"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) udid="${2:-}"; shift 2 ;;
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --process) process_name="${2:-}"; shift 2 ;;
    --subsystem) subsystem="${2:-}"; shift 2 ;;
    --predicate) predicate="${2:-}"; shift 2 ;;
    --session-dir) session_dir="${2:-}"; shift 2 ;;
    --level) level="${2:-}"; shift 2 ;;
    --prepare-cmd) prepare_cmd="${2:-}"; shift 2 ;;
    --build-xcode) build_xcode="1"; shift 1 ;;
    --workspace) workspace="${2:-}"; shift 2 ;;
    --project) project="${2:-}"; shift 2 ;;
    --scheme) scheme="${2:-}"; shift 2 ;;
    --configuration) configuration="${2:-}"; shift 2 ;;
    --derived-data-path) derived_data_path="${2:-}"; shift 2 ;;
    --cwd) cwd="${2:-}"; shift 2 ;;
    --allow-relaunch) allow_relaunch="1"; shift 1 ;;
    --dual) mode="dual"; shift 1 ;;
    --unified) mode="unified"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$udid" ]]; then
  echo "Missing --udid" >&2
  usage
  exit 1
fi

if [[ -z "$session_dir" ]]; then
  stamp="$(date +%Y%m%d-%H%M%S)"
  session_dir=".telemetry/ios/$stamp"
fi

if [[ -n "$prepare_cmd" ]]; then
  mkdir -p "$session_dir"
  {
    echo "prepare_cmd=$prepare_cmd"
    echo "prepare_started_at=$(date -Iseconds)"
  } >> "$session_dir/metadata.txt"
  echo "Prepare command: $prepare_cmd" >&2
  /bin/zsh -lc "$prepare_cmd"
fi

if [[ "$build_xcode" == "1" ]]; then
  mkdir -p "$session_dir"
  output_env="$session_dir/xcode-build.env"
  command=(
    "$(dirname "$0")/build_install_xcode_app.sh"
    --udid "$udid"
    --cwd "$cwd"
    --output-env "$output_env"
  )
  if [[ -n "$configuration" ]]; then command+=(--configuration "$configuration"); fi
  if [[ -n "$workspace" ]]; then command+=(--workspace "$workspace"); fi
  if [[ -n "$project" ]]; then command+=(--project "$project"); fi
  if [[ -n "$scheme" ]]; then command+=(--scheme "$scheme"); fi
  if [[ -n "$derived_data_path" ]]; then command+=(--derived-data-path "$derived_data_path"); fi
  echo "Xcode build/install: ${command[*]}" >&2
  "${command[@]}"
  if [[ -f "$output_env" ]]; then
    # shellcheck disable=SC1090
    source "$output_env"
    if [[ -z "$bundle_id" && -n "${BUNDLE_ID:-}" ]]; then
      bundle_id="$BUNDLE_ID"
    fi
  fi
fi

case "$mode" in
  console)
    if [[ -z "$bundle_id" ]]; then
      echo "Missing --bundle-id for console mode" >&2
      exit 1
    fi
    command=(
      "$(dirname "$0")/start_console_capture.sh"
      --udid "$udid"
      --bundle-id "$bundle_id"
      --session-dir "$session_dir"
    )
    if [[ "$allow_relaunch" == "1" ]]; then
      command+=(--allow-relaunch)
    fi
    exec "${command[@]}"
    ;;
  dual)
    if [[ -z "$bundle_id" ]]; then
      echo "Missing --bundle-id for dual mode" >&2
      exit 1
    fi
    command=(
      "$(dirname "$0")/start_dual_capture.sh"
      --udid "$udid"
      --bundle-id "$bundle_id"
      --session-dir "$session_dir"
      --level "$level"
    )
    if [[ -n "$process_name" ]]; then
      command+=(--process "$process_name")
    fi
    if [[ -n "$subsystem" ]]; then
      command+=(--subsystem "$subsystem")
    fi
    if [[ -n "$predicate" ]]; then
      command+=(--predicate "$predicate")
    fi
    if [[ "$allow_relaunch" == "1" ]]; then
      command+=(--allow-relaunch)
    fi
    exec "${command[@]}"
    ;;
  unified)
    command=(
      "$(dirname "$0")/start_log_stream.sh"
      --udid "$udid"
      --session-dir "$session_dir"
      --level "$level"
    )
    if [[ -n "$process_name" ]]; then
      command+=(--process "$process_name")
    fi
    if [[ -n "$subsystem" ]]; then
      command+=(--subsystem "$subsystem")
    fi
    if [[ -n "$predicate" ]]; then
      command+=(--predicate "$predicate")
    fi
    exec "${command[@]}"
    ;;
  *)
    echo "Unsupported mode: $mode" >&2
    exit 1
    ;;
esac
