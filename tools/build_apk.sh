#!/bin/bash
# Builds the installable Android APK: build/rajinikanth.apk (debug-signed).
# Needs: Godot 4.3 + export templates, a JDK, and ANDROID_SDK_ROOT with build-tools.
set -e
cd "$(dirname "$0")/.."
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/android-sdk}}"
KS="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
if [ ! -f "$KS" ]; then
  mkdir -p "$(dirname "$KS")"
  keytool -genkeypair -keystore "$KS" -storepass android -keypass android -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi
JAVA_HOME_DIR="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(which java)")")")}"
mkdir -p "$HOME/.config/godot" build
cat > "$HOME/.config/godot/editor_settings-4.3.tres" <<EOF
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA_HOME_DIR"
export/android/debug_keystore = "$KS"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
godot --headless --path . --import >/dev/null 2>&1 || true
tools/check.sh
godot --headless --path . --export-debug Android build/rajinikanth.apk 2>&1 | grep -vE "^ADDING|^$" | tail -15
ls -la build/rajinikanth.apk
