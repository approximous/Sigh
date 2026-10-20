#!/usr/bin/env bash
set -euo pipefail

# Configuration variables
API_LEVEL="34"
SDK_DIR="$HOME/android-sdk"
AVD_NAME="secure_codespace_avd"

echo "=== [1/4] Initializing Android SDK Environment ==="
mkdir -p "$SDK_DIR/cmdline-tools"
cd "$SDK_DIR/cmdline-tools"

if [ ! -d "latest" ]; then
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O tools.zip
  unzip -q tools.zip
  mv cmdline-tools latest
  rm tools.zip
fi

export ANDROID_HOME="$SDK_DIR"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

# Export persistence for shell sessions
echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator' >> ~/.bashrc

echo "=== [2/4] Installing Required SDK Packages ==="
yes | sdkmanager --licenses > /dev/null
sdkmanager "platform-tools" "platforms;android-${API_LEVEL}" "emulator" "system-images;android-${API_LEVEL};google_apis;x86_64"

echo "=== [3/4] Provisioning Headless AVD ==="
if [ ! -d "$HOME/.android/avd/${AVD_NAME}.avd" ]; then
  echo "no" | avdmanager create avd \
    -n "$AVD_NAME" \
    -k "system-images;android-${API_LEVEL};google_apis;x86_64" \
    --force
fi

echo "=== [4/4] Starting Headless Emulator & ADB Binding ==="
# Boot emulator headlessly with software rendering (or host KVM if supported)
emulator -avd "$AVD_NAME" -no-window -no-audio -gpu swiftshader_indirect -no-boot-anim &

# Wait for ADB and verify boot state
echo "Waiting for ADB socket daemon..."
adb wait-for-device

# Background loop to verify device readiness securely
(
  OUT=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  while [ "$OUT" != "1" ]; do
    sleep 3
    OUT=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  done
  echo "=== Android Framework Fully Booted & Ready for Connection ==="
) &
