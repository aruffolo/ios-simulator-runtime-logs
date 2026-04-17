#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build_install_xcode_app.sh --udid <UDID> [--workspace <path> | --project <path>] [--scheme <name>] [--configuration <name>] [--derived-data-path <path>] [--cwd <path>] [--output-env <path>] [--clean]
EOF
}

udid=""
workspace=""
project=""
scheme=""
configuration=""
derived_data_path=""
cwd="."
output_env=""
clean_first="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) udid="${2:-}"; shift 2 ;;
    --workspace) workspace="${2:-}"; shift 2 ;;
    --project) project="${2:-}"; shift 2 ;;
    --scheme) scheme="${2:-}"; shift 2 ;;
    --configuration) configuration="${2:-}"; shift 2 ;;
    --derived-data-path) derived_data_path="${2:-}"; shift 2 ;;
    --cwd) cwd="${2:-}"; shift 2 ;;
    --output-env) output_env="${2:-}"; shift 2 ;;
    --clean) clean_first="1"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$udid" ]]; then
  echo "Missing --udid" >&2
  usage
  exit 1
fi

destination="id=$udid"
resolver=(
  python3 "$(dirname "$0")/resolve_xcode_app.py"
  --cwd "$cwd"
  --destination "$destination"
)
if [[ -n "$configuration" ]]; then resolver+=(--configuration "$configuration"); fi
if [[ -n "$workspace" ]]; then resolver+=(--workspace "$workspace"); fi
if [[ -n "$project" ]]; then resolver+=(--project "$project"); fi
if [[ -n "$scheme" ]]; then resolver+=(--scheme "$scheme"); fi
if [[ -n "$derived_data_path" ]]; then resolver+=(--derived-data-path "$derived_data_path"); fi

set +e
resolution_json="$("${resolver[@]}" 2>&1)"
resolver_status=$?
set -e
if [[ $resolver_status -ne 0 ]]; then
  echo "$resolution_json" >&2
  likely_schemes="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys
try:
    payload=json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
details=payload.get("details") or {}
schemes=details.get("likely_app_schemes") or details.get("all_schemes") or []
print("\n".join(schemes))' 2>/dev/null || true)"
  if [[ -n "$likely_schemes" ]]; then
    echo "Ambiguous scheme. Ask the user which --scheme to use. Candidates:" >&2
    printf '%s\n' "$likely_schemes" >&2
  fi
  exit $resolver_status
fi
entry_kind="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry_kind"])')"
entry_path="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry_path"])')"
resolved_scheme="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["scheme"])')"
resolved_configuration="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["configuration"])')"
bundle_id="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["bundle_id"])')"
app_path="$(printf '%s' "$resolution_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["app_path"])')"

build_command=(xcodebuild "-$entry_kind" "$entry_path" -scheme "$resolved_scheme" -destination "$destination")
if [[ -n "$resolved_configuration" ]]; then build_command+=(-configuration "$resolved_configuration"); fi
if [[ -n "$derived_data_path" ]]; then build_command+=(-derivedDataPath "$derived_data_path"); fi
if [[ "$clean_first" == "1" ]]; then
  build_command+=(clean build)
else
  build_command+=(build)
fi

echo "Building: ${build_command[*]}" >&2
"${build_command[@]}"

if [[ ! -d "$app_path" ]]; then
  echo "Built app not found at $app_path" >&2
  exit 1
fi

echo "Installing: $app_path" >&2
xcrun simctl install "$udid" "$app_path"
echo "Resolved bundle id: $bundle_id" >&2

if [[ -n "$output_env" ]]; then
  cat > "$output_env" <<EOF
CONFIGURATION=$resolved_configuration
BUNDLE_ID=$bundle_id
APP_PATH=$app_path
SCHEME=$resolved_scheme
ENTRY_KIND=$entry_kind
ENTRY_PATH=$entry_path
EOF
fi
