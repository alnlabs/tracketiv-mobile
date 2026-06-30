#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$APP_DIR/android"
KEY_PROPS="$ANDROID_DIR/key.properties"

FORMAT="apk"
GENERATE_KEYSTORE=false
BUMP_VERSION=true
KEY_ALIAS="upload"
KEYSTORE_FILE="upload-keystore.jks"

usage() {
  cat <<'EOF'
Build Tracketiv for Android in release mode.

Usage:
  ./scripts/build-android.sh [options]

Options:
  --apk              Build a release APK (default)
  --aab              Build a release App Bundle for Play Store
  --no-bump          Skip automatic version bump
  --patch            Bump patch version before build (1.0.0 -> 1.0.1)
  --minor            Bump minor version before build (1.0.0 -> 1.1.0)
  --major            Bump major version before build (1.0.0 -> 2.0.0)
  --generate-keystore  Create android/upload-keystore.jks (interactive)
  -h, --help         Show this help

Setup (one time):
  1. ./scripts/build-android.sh --generate-keystore
  2. cp android/key.properties.example android/key.properties
  3. Fill in passwords in android/key.properties

Outputs:
  APK: build/app/outputs/flutter-apk/app-release.apk
  AAB: build/app/outputs/bundle/release/app-release.aab
EOF
}

BUMP_MODE="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)
      FORMAT="apk"
      shift
      ;;
    --aab)
      FORMAT="aab"
      shift
      ;;
    --no-bump)
      BUMP_VERSION=false
      shift
      ;;
    --patch)
      BUMP_MODE="patch"
      shift
      ;;
    --minor)
      BUMP_MODE="minor"
      shift
      ;;
    --major)
      BUMP_MODE="major"
      shift
      ;;
    --generate-keystore)
      GENERATE_KEYSTORE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$GENERATE_KEYSTORE" == true ]]; then
  if [[ -f "$ANDROID_DIR/$KEYSTORE_FILE" ]]; then
    echo "Keystore already exists: android/$KEYSTORE_FILE" >&2
    exit 1
  fi

  echo "Generating release keystore at android/$KEYSTORE_FILE"
  keytool -genkey -v \
    -keystore "$ANDROID_DIR/$KEYSTORE_FILE" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias "$KEY_ALIAS"

  echo
  echo "Next: cp android/key.properties.example android/key.properties"
  echo "Set storeFile=$KEYSTORE_FILE, keyAlias=$KEY_ALIAS, and your passwords."
  exit 0
fi

cd "$APP_DIR"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example to .env and add your keys." >&2
  exit 1
fi

if [[ ! -f "$KEY_PROPS" ]]; then
  echo "Warning: android/key.properties not found." >&2
  echo "Release builds will use the debug signing key (fine for local testing only)." >&2
  echo "For Play Store: ./scripts/build-android.sh --generate-keystore" >&2
  echo
fi

if [[ "$BUMP_VERSION" == true ]]; then
  echo "Bumping version ($BUMP_MODE)..."
  "$SCRIPT_DIR/bump_version.sh" "--$BUMP_MODE"
  echo
fi

if [[ "$FORMAT" == "aab" ]]; then
  echo "Building release App Bundle..."
  flutter build appbundle --release
  echo
  echo "Output: build/app/outputs/bundle/release/app-release.aab"
else
  echo "Building release APK..."
  flutter build apk --release
  echo
  echo "Output: build/app/outputs/flutter-apk/app-release.apk"
fi
