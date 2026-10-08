#!/bin/bash
set -e

VERSION="${1:-0.1.0-mvp}"
LOCAL_ROOT="/home/pi/.gemini/antigravity/scratch/local-root"
export LD_LIBRARY_PATH="$LOCAL_ROOT/usr/lib:$LOCAL_ROOT/lib/aarch64-linux-gnu:$LOCAL_ROOT/usr/lib/aarch64-linux-gnu:$LOCAL_ROOT/usr/lib/aarch64-linux-gnu/android"
JAVA_BIN="$LOCAL_ROOT/usr/lib/jvm/java-21-openjdk-arm64/bin"
AAPT="$LOCAL_ROOT/usr/lib/android-sdk/build-tools/debian/aapt"
ZIPALIGN="$LOCAL_ROOT/usr/lib/android-sdk/build-tools/debian/zipalign"
APKSIGNER_JAR="$LOCAL_ROOT/usr/share/java/apksigner.jar"
FRAMEWORK_RES="$LOCAL_ROOT/usr/share/android-framework-res/framework-res.apk"
ANDROID_JAR="$LOCAL_ROOT/android.jar"
R8_JAR="$LOCAL_ROOT/r8.jar"

PROJECT_DIR="/home/pi/.gemini/antigravity/scratch/omnia_energy"
BUILD_DIR="$PROJECT_DIR/apk-build"
OUT_DIR="$BUILD_DIR/out"
RELEASE_DIR="$PROJECT_DIR/releases"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/gen" "$OUT_DIR/classes" "$OUT_DIR/dex" "$RELEASE_DIR"

echo "[1/6] Generating R.java with aapt..."
"$AAPT" package -f -m \
  -J "$OUT_DIR/gen" \
  -M "$BUILD_DIR/AndroidManifest.xml" \
  -S "$BUILD_DIR/res" \
  -A "$BUILD_DIR/assets" \
  -I "$FRAMEWORK_RES"

echo "[2/6] Compiling Java sources with javac..."
"$JAVA_BIN/javac" --release 11 \
  -classpath "$ANDROID_JAR" \
  -d "$OUT_DIR/classes" \
  "$OUT_DIR/gen/com/omniaenergy/omnia_energy/R.java" \
  "$BUILD_DIR/src/com/omniaenergy/omnia_energy/SqliteLocalDb.java" \
  "$BUILD_DIR/src/com/omniaenergy/omnia_energy/TuyaLocalClient.java" \
  "$BUILD_DIR/src/com/omniaenergy/omnia_energy/MainActivity.java" \
  "$BUILD_DIR/src/android/webkit/JavascriptInterface.java"

echo "[3/6] Converting bytecode to Dalvik DEX (classes.dex) with D8..."
"$JAVA_BIN/java" -cp "$R8_JAR" com.android.tools.r8.D8 \
  --lib "$ANDROID_JAR" \
  --min-api 24 \
  --output "$OUT_DIR/dex" \
  "$OUT_DIR/classes/com/omniaenergy/omnia_energy/"*.class

echo "[4/6] Packaging APK with aapt and adding classes.dex..."
"$AAPT" package -f \
  -M "$BUILD_DIR/AndroidManifest.xml" \
  -S "$BUILD_DIR/res" \
  -A "$BUILD_DIR/assets" \
  -I "$FRAMEWORK_RES" \
  -F "$OUT_DIR/unaligned.apk"

cp "$OUT_DIR/dex/classes.dex" "$OUT_DIR/classes.dex"
(cd "$OUT_DIR" && "$AAPT" add unaligned.apk classes.dex)

echo "[5/6] Zipaligning and signing OmniaEnergy-v${VERSION}.apk..."
"$ZIPALIGN" -f 4 "$OUT_DIR/unaligned.apk" "$OUT_DIR/aligned.apk"

KEYSTORE="$BUILD_DIR/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  "$JAVA_BIN/keytool" -genkeypair \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=OmniaEnergy,O=OmniaEnergy,C=US"
fi

RELEASE_APK="$RELEASE_DIR/OmniaEnergy-v${VERSION}.apk"
LATEST_APK="$PROJECT_DIR/OmniaEnergy.apk"

"$JAVA_BIN/java" -jar "$APKSIGNER_JAR" sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$RELEASE_APK" \
  "$OUT_DIR/aligned.apk"

cp "$RELEASE_APK" "$LATEST_APK"

echo "[6/6] Checking connected phone via ADB..."
TARGET_DEVICE=$(env -u LD_LIBRARY_PATH adb devices | grep -w "device" | head -n 1 | awk '{print $1}')
if [ -n "$TARGET_DEVICE" ]; then
  echo "Found device: $TARGET_DEVICE. Installing..."
  env -u LD_LIBRARY_PATH adb -s "$TARGET_DEVICE" install -r "$RELEASE_APK"
  env -u LD_LIBRARY_PATH adb -s "$TARGET_DEVICE" shell am start -n com.omniaenergy.omnia_energy/.MainActivity
  echo "SUCCESS! OmniaEnergy-v${VERSION}.apk installed and launched on connected phone ($TARGET_DEVICE)."
else
  echo "No connected ADB device found. APK built & signed at $RELEASE_APK"
fi
