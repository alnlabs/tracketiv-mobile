#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

SELECTED=()
LIST_ONLY=false
EXTRA_ARGS=()
PROVIDED=false
BUILD_MODE="debug"
BUILD_MODE_PROVIDED=false
PIDS=()

usage() {
  cat <<'EOF'
Run Tracketiv on one or more platforms/devices.

Usage:
  ./scripts/run.sh [options] [-- flutter-args...]

Options:
  -p, --platform LIST   Platform(s): web, android, ios, macos, linux, windows
                        Comma-separated for multiple (e.g. web,android)
  -d, --device ID       Specific device ID(s), comma-separated
  -m, --mode MODE       Build mode: debug or release (default: debug)
      --debug           Run in debug mode
      --release         Run in release mode
  -l, --list            List available platforms and devices, then exit
  -h, --help            Show this help

Without -p or -d, you get an interactive multi-select menu.
Without -m/--debug/--release, you are prompted to pick debug or release.

Platform aliases resolve to all connected devices of that type:
  web      → Chrome (or other browser Flutter lists)
  android  → connected Android phones/emulators
  ios      → iOS simulators and physical devices
  macos    → macOS desktop
  linux    → Linux desktop
  windows  → Windows desktop

Examples:
  ./scripts/run.sh
  ./scripts/run.sh -p web
  ./scripts/run.sh -p android
  ./scripts/run.sh -p web,android
  ./scripts/run.sh -d chrome,b012d486
  ./scripts/run.sh -p android -m release
  ./scripts/run.sh --release -p ios
EOF
}

cleanup() {
  local pid
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}

devices_json() {
  flutter devices --machine 2>/dev/null
}

list_targets() {
  python3 - <<'PY'
import json
import subprocess
import sys

PLATFORM_ORDER = ["web", "android", "ios", "macos", "linux", "windows"]

def classify(device):
    target = (device.get("targetPlatform") or "").lower()
    device_id = (device.get("id") or "").lower()
    if target.startswith("web") or device_id in ("chrome", "edge", "web-server"):
        return "web"
    if target.startswith("android"):
        return "android"
    if target.startswith("ios"):
        return "ios"
    if target in ("darwin",) or device_id == "macos":
        return "macos"
    if target.startswith("linux") or device_id == "linux":
        return "linux"
    if target.startswith("windows") or device_id == "windows":
        return "windows"
    return "other"

try:
    out = subprocess.check_output(["flutter", "devices", "--machine"], text=True)
    devices = json.loads(out)
except (subprocess.CalledProcessError, json.JSONDecodeError) as exc:
    print(f"Failed to list devices: {exc}", file=sys.stderr)
    sys.exit(1)

if not devices:
    print("  (no devices found)")
    sys.exit(0)

by_platform = {key: [] for key in PLATFORM_ORDER}
by_platform["other"] = []

for device in devices:
    platform = classify(device)
    by_platform.setdefault(platform, []).append(device)

print("Platforms:")
shown = 0
for platform in PLATFORM_ORDER + ["other"]:
    group = by_platform.get(platform, [])
    if not group:
        continue
    shown += 1
    print(f"  {platform} ({len(group)})")
    for device in group:
        name = device.get("name", "Unknown")
        device_id = device.get("id", "?")
        detail = device.get("sdk") or device.get("targetPlatform", "?")
        print(f"    - {name} ({device_id}) — {detail}")

if shown == 0:
    print("  (no devices found)")
PY
}

resolve_selection() {
  local input="$1"
  python3 - <<'PY' "$input"
import json
import subprocess
import sys

PLATFORM_ORDER = ["web", "android", "ios", "macos", "linux", "windows"]
ALIASES = {
    "web": "web",
    "chrome": "web",
    "browser": "web",
    "android": "android",
    "ios": "ios",
    "iphone": "ios",
    "ipad": "ios",
    "macos": "macos",
    "mac": "macos",
    "darwin": "macos",
    "linux": "linux",
    "windows": "windows",
    "win": "windows",
}

def classify(device):
    target = (device.get("targetPlatform") or "").lower()
    device_id = (device.get("id") or "").lower()
    if target.startswith("web") or device_id in ("chrome", "edge", "web-server"):
        return "web"
    if target.startswith("android"):
        return "android"
    if target.startswith("ios"):
        return "ios"
    if target in ("darwin",) or device_id == "macos":
        return "macos"
    if target.startswith("linux") or device_id == "linux":
        return "linux"
    if target.startswith("windows") or device_id == "windows":
        return "windows"
    return "other"

raw = sys.argv[1].strip()
if not raw:
    sys.exit(0)

try:
    out = subprocess.check_output(["flutter", "devices", "--machine"], text=True)
    devices = json.loads(out)
except (subprocess.CalledProcessError, json.JSONDecodeError) as exc:
    print(f"Failed to list devices: {exc}", file=sys.stderr)
    sys.exit(1)

by_id = {d["id"]: d for d in devices}
by_platform = {key: [] for key in PLATFORM_ORDER}
by_platform["other"] = []
for device in devices:
    by_platform.setdefault(classify(device), []).append(device)

menu = []
for platform in PLATFORM_ORDER + ["other"]:
    for device in by_platform.get(platform, []):
        menu.append(device)

tokens = [part.strip() for part in raw.replace(";", ",").split(",") if part.strip()]
selected = []
seen = set()

for token in tokens:
    lower = token.lower()
    if lower.isdigit():
        index = int(lower)
        if index < 1 or index > len(menu):
            print(f"Invalid menu choice: {index}", file=sys.stderr)
            sys.exit(1)
        device_id = menu[index - 1]["id"]
        if device_id not in seen:
            seen.add(device_id)
            selected.append(device_id)
        continue

    if lower in ALIASES:
        platform = ALIASES[lower]
        matches = by_platform.get(platform, [])
        if not matches:
            print(f"No connected {platform} device found.", file=sys.stderr)
            sys.exit(1)
        for device in matches:
            device_id = device["id"]
            if device_id not in seen:
                seen.add(device_id)
                selected.append(device_id)
        continue

    if token in by_id:
        if token not in seen:
            seen.add(token)
            selected.append(token)
        continue

    print(f"Unknown platform or device: {token}", file=sys.stderr)
    print("Use --list to see available options.", file=sys.stderr)
    sys.exit(1)

for device_id in selected:
    print(device_id)
PY
}

pick_targets_interactive() {
  local json
  if ! json="$(devices_json)"; then
    echo "Could not list Flutter devices." >&2
    exit 1
  fi

  local menu
  if ! menu="$(python3 - <<'PY' "$json"
import json
import sys

PLATFORM_ORDER = ["web", "android", "ios", "macos", "linux", "windows"]

def classify(device):
    target = (device.get("targetPlatform") or "").lower()
    device_id = (device.get("id") or "").lower()
    if target.startswith("web") or device_id in ("chrome", "edge", "web-server"):
        return "web"
    if target.startswith("android"):
        return "android"
    if target.startswith("ios"):
        return "ios"
    if target in ("darwin",) or device_id == "macos":
        return "macos"
    if target.startswith("linux") or device_id == "linux":
        return "linux"
    if target.startswith("windows") or device_id == "windows":
        return "windows"
    return "other"

devices = json.loads(sys.argv[1])
by_platform = {key: [] for key in PLATFORM_ORDER}
by_platform["other"] = []
for device in devices:
    by_platform.setdefault(classify(device), []).append(device)

menu = []
for platform in PLATFORM_ORDER + ["other"]:
    for device in by_platform.get(platform, []):
        menu.append((platform, device))

if not menu:
    sys.exit(2)

for index, (platform, device) in enumerate(menu, start=1):
    name = device.get("name", "Unknown")
    device_id = device.get("id", "?")
    detail = device.get("sdk") or device.get("targetPlatform", "?")
    print(f"  {index}) [{platform}] {name} ({device_id}) — {detail}")
PY
)"; then
    echo "No Flutter devices found." >&2
    exit 1
  fi

  echo "Select platform(s) / device(s) (comma-separated numbers, e.g. 1,3):"
  echo "$menu"
  echo "  0) Let Flutter choose the default device"
  printf "Choice: "
  read -r choice

  if [[ -z "$choice" || "$choice" == "0" ]]; then
    SELECTED=()
    return
  fi

  SELECTED=()
  while IFS= read -r line; do
    SELECTED+=("$line")
  done < <(resolve_selection "$choice")
}

set_build_mode() {
  local mode
  mode="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$mode" in
    debug|dev)
      BUILD_MODE="debug"
      ;;
    release|rel|prod)
      BUILD_MODE="release"
      ;;
    *)
      echo "Invalid build mode: $1 (use debug or release)" >&2
      exit 1
      ;;
  esac
  BUILD_MODE_PROVIDED=true
}

pick_build_mode_interactive() {
  echo "Select build mode:"
  echo "  1) debug"
  echo "  2) release"
  printf "Choice [1]: "
  read -r choice

  case "${choice:-1}" in
    1|""|debug)
      BUILD_MODE="debug"
      ;;
    2|release)
      BUILD_MODE="release"
      ;;
    *)
      echo "Invalid choice: $choice" >&2
      exit 1
      ;;
  esac
}

strip_mode_from_extra_args() {
  if [[ ${#EXTRA_ARGS[@]} -eq 0 ]]; then
    return
  fi

  local filtered=()
  local arg

  for arg in "${EXTRA_ARGS[@]}"; do
    [[ -n "$arg" ]] || continue
    case "$arg" in
      --release)
        set_build_mode release
        ;;
      --debug)
        set_build_mode debug
        ;;
      *)
        filtered+=("$arg")
        ;;
    esac
  done

  EXTRA_ARGS=()
  if [[ ${#filtered[@]} -gt 0 ]]; then
    EXTRA_ARGS=("${filtered[@]}")
  fi
}

device_is_web() {
  local id
  id="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$id" == "chrome" || "$id" == "edge" || "$id" == "web-server" || "$id" == *"chrome"* ]]
}

build_flutter_run_cmd() {
  local device_id="${1:-}"
  local -a cmd=(flutter run)

  if [[ -n "$device_id" ]]; then
    cmd+=(-d "$device_id")
  fi

  if [[ "$BUILD_MODE" == "release" ]]; then
    cmd+=(--release)
  fi

  if [[ -n "$device_id" ]] && device_is_web "$device_id"; then
    local has_web_port=false
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
      local arg
      for arg in "${EXTRA_ARGS[@]}"; do
        if [[ "$arg" == --web-port* ]]; then
          has_web_port=true
          break
        fi
      done
    fi
    if [[ "$has_web_port" == false ]]; then
      cmd+=(--web-port=8080)
    fi
  fi

  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    cmd+=("${EXTRA_ARGS[@]}")
  fi

  echo "Running (${BUILD_MODE}): ${cmd[*]}"
  "${cmd[@]}"
}

run_flutter_cmd() {
  build_flutter_run_cmd "${1:-}"
}

run_on_device() {
  local device_id="$1"

  run_flutter_cmd "$device_id" &
  PIDS+=("$!")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--platform)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
      SELECTED=()
      while IFS= read -r line; do
        SELECTED+=("$line")
      done < <(resolve_selection "$2")
      PROVIDED=true
      shift 2
      ;;
    -d|--device)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
      SELECTED=()
      while IFS= read -r line; do
        SELECTED+=("$line")
      done < <(resolve_selection "$2")
      PROVIDED=true
      shift 2
      ;;
    -m|--mode)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
      set_build_mode "$2"
      shift 2
      ;;
    --debug)
      set_build_mode debug
      shift
      ;;
    --release)
      set_build_mode release
      shift
      ;;
    -l|--list)
      LIST_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

strip_mode_from_extra_args

if [[ "$LIST_ONLY" == true ]]; then
  list_targets
  exit 0
fi

if [[ "$PROVIDED" == false ]]; then
  pick_targets_interactive
fi

if [[ "$BUILD_MODE_PROVIDED" == false ]]; then
  pick_build_mode_interactive
fi

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example to .env and add your keys." >&2
  exit 1
fi

if [[ ${#SELECTED[@]} -eq 0 ]]; then
  run_flutter_cmd ""
  exit $?
fi

if [[ ${#SELECTED[@]} -eq 1 ]]; then
  run_flutter_cmd "${SELECTED[0]}"
  exit $?
fi

for device_id in "${SELECTED[@]}"; do
  run_on_device "$device_id"
done

echo "Started ${#SELECTED[@]} Flutter run process(es). Press Ctrl+C to stop all."
wait
