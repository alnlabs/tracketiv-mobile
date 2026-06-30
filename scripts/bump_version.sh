#!/usr/bin/env bash
# Bumps version in pubspec.yaml for release builds.
#
# Usage:
#   ./scripts/bump_version.sh --auto          # analyze git changes + increment build
#   ./scripts/bump_version.sh --build-only    # increment build number only
#   ./scripts/bump_version.sh --patch         # patch + build
#   ./scripts/bump_version.sh --minor         # minor + build (resets patch)
#   ./scripts/bump_version.sh --major         # major + build (resets minor/patch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$APP_DIR/pubspec.yaml"
STATE_FILE="$APP_DIR/.version/release.json"

MODE="auto"

usage() {
  cat <<'EOF'
Bump Tracketiv app version in pubspec.yaml.

Modes:
  --auto         Default for release builds: bump semver from git commits since
                 last release, and always increment the build number (+N).
  --build-only   Only increment the build number.
  --patch        Increment patch (1.0.0 -> 1.0.1) and build number.
  --minor        Increment minor (1.0.1 -> 1.1.0) and build number.
  --major        Increment major (1.1.0 -> 2.0.0) and build number.

Commit rules (--auto):
  BREAKING / feat! / fix!  -> major
  feat:                    -> minor
  fix: / perf: / other      -> patch (when lib/ or assets/ changed)
  docs-only / ci-only       -> build number only

State is stored in .version/release.json (commit this file).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) MODE="auto"; shift ;;
    --build-only) MODE="build-only"; shift ;;
    --patch) MODE="patch"; shift ;;
    --minor) MODE="minor"; shift ;;
    --major) MODE="major"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

mkdir -p "$(dirname "$STATE_FILE")"

python3 - <<'PY' "$PUBSPEC" "$STATE_FILE" "$MODE" "$APP_DIR"
import json
import os
import re
import subprocess
import sys

pubspec_path, state_path, mode, app_dir = sys.argv[1:5]

with open(pubspec_path, encoding="utf-8") as f:
    pubspec = f.read()

match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
if not match:
    print("Could not parse version from pubspec.yaml (expected X.Y.Z+N)", file=sys.stderr)
    sys.exit(1)

major, minor, patch, build = map(int, match.groups())

def save_state(ver_major, ver_minor, ver_patch, ver_build, commit):
    state = {
        "version": f"{ver_major}.{ver_minor}.{ver_patch}",
        "build": ver_build,
        "commit": commit,
    }
    os.makedirs(os.path.dirname(state_path), exist_ok=True)
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
        f.write("\n")

def git(*args):
    try:
        return subprocess.check_output(["git", *args], cwd=app_dir, text=True).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

def valid_commit(commit):
    if not commit or commit == "initial":
        return False
    try:
        subprocess.check_call(
            ["git", "cat-file", "-e", commit],
            cwd=app_dir,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def commits_since(last_commit):
    if not valid_commit(last_commit):
        out = git("log", "--pretty=format:%s")
    else:
        out = git("log", f"{last_commit}..HEAD", "--pretty=format:%s")
    if not out:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]

def files_changed_since(last_commit):
    if not valid_commit(last_commit):
        out = git("log", "--name-only", "--pretty=format:", "HEAD")
    else:
        out = git("log", f"{last_commit}..HEAD", "--name-only", "--pretty=format:")
    if not out:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]

def classify_commits(messages):
    level = 0  # 0=none, 1=patch, 2=minor, 3=major
    for msg in messages:
        lower = msg.lower()
        if "breaking" in lower or re.search(r"\w+!:", msg):
            level = max(level, 3)
        elif lower.startswith("feat"):
            level = max(level, 2)
        elif lower.startswith(("fix", "perf", "refactor")):
            level = max(level, 1)
    return level

last_commit = None
if os.path.exists(state_path):
    with open(state_path, encoding="utf-8") as f:
        try:
            last_commit = json.load(f).get("commit")
        except json.JSONDecodeError:
            last_commit = None

messages = commits_since(last_commit)
changed_files = files_changed_since(last_commit)
app_changed = any(
    p.startswith(("lib/", "assets/", "pubspec.yaml", "android/", "ios/"))
    for p in changed_files
)

if mode == "auto":
    bump = classify_commits(messages)
    if bump == 0 and app_changed:
        bump = 1
    if bump >= 3:
        major += 1
        minor = 0
        patch = 0
    elif bump == 2:
        minor += 1
        patch = 0
    elif bump == 1:
        patch += 1
elif mode == "patch":
    patch += 1
elif mode == "minor":
    minor += 1
    patch = 0
elif mode == "major":
    major += 1
    minor = 0
    patch = 0
# build-only: no semver change

build += 1

new_version = f"{major}.{minor}.{patch}+{build}"
pubspec_new = re.sub(r"^version:\s*.+$", f"version: {new_version}", pubspec, count=1, flags=re.M)

with open(pubspec_path, "w", encoding="utf-8") as f:
    f.write(pubspec_new)

head = git("rev-parse", "HEAD") or "unknown"
save_state(major, minor, patch, build, head)

print(f"Version bumped to {new_version}")
if messages:
    print(f"  Commits since last release: {len(messages)}")
else:
    print("  No new commits since last release (build number still incremented)")
PY
