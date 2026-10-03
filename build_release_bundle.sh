#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
PROJECT_DIR="/home/pi/.gemini/antigravity/scratch/omnia_energy"
LOCAL_ROOT="/home/pi/.gemini/antigravity/scratch/local-root"

export LD_LIBRARY_PATH="$LOCAL_ROOT/usr/lib:$LOCAL_ROOT/lib/aarch64-linux-gnu:$LOCAL_ROOT/usr/lib/aarch64-linux-gnu:$LOCAL_ROOT/usr/lib/aarch64-linux-gnu/android:$LD_LIBRARY_PATH"

JAVA_BIN="$LOCAL_ROOT/usr/lib/jvm/java-21-openjdk-arm64/bin"
AAPT2="$LOCAL_ROOT/bin/aapt2-wrapper"
BUNDLETOOL="$LOCAL_ROOT/bundletool.jar"
ANDROID_JAR="$LOCAL_ROOT/android-34.jar"
R8_JAR="$LOCAL_ROOT/r8.jar"

BUILD_DIR="$PROJECT_DIR/apk-build"
OUT_DIR="$BUILD_DIR/out-bundle"
RELEASE_DIR="$PROJECT_DIR/releases"
KEYSTORE="$PROJECT_DIR/keystore/omnia-release-key.jks"
STOREPASS="OmniaEnergy2026SecureReleaseKey!"
KEYALIAS="omnia-release"

echo "================================================================="
echo "Building Production Google Play App Bundle (AAB) v${VERSION}"
echo "================================================================="

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/compiled_res" "$OUT_DIR/gen" "$OUT_DIR/classes" "$OUT_DIR/dex" "$OUT_DIR/proto_apk" "$OUT_DIR/base_module/manifest" "$OUT_DIR/base_module/dex" "$RELEASE_DIR"

echo "[1/7] Compiling Android resources with aapt2..."
"$AAPT2" compile --dir "$BUILD_DIR/res" -o "$OUT_DIR/compiled_res.zip"

echo "[2/7] Generating R.java and linking resources in Protobuf format..."
"$AAPT2" link \
  --proto-format \
  -I "$ANDROID_JAR" \
  --manifest "$BUILD_DIR/AndroidManifest.xml" \
  -o "$OUT_DIR/proto_base.apk" \
  --java "$OUT_DIR/gen" \
  --auto-add-overlay \
  -A "$BUILD_DIR/assets" \
  "$OUT_DIR/compiled_res.zip"

echo "[3/7] Compiling Java classes with javac..."
"$JAVA_BIN/javac" --release 11 \
  -classpath "$ANDROID_JAR" \
  -d "$OUT_DIR/classes" \
  "$OUT_DIR/gen/com/omniaenergy/omnia_energy/R.java" \
  "$BUILD_DIR/src/com/omniaenergy/omnia_energy/SqliteLocalDb.java" \
  "$BUILD_DIR/src/com/omniaenergy/omnia_energy/MainActivity.java" \
  "$BUILD_DIR/src/android/webkit/JavascriptInterface.java"

echo "[4/7] Converting bytecode to Dalvik DEX with D8..."
"$JAVA_BIN/java" -cp "$R8_JAR" com.android.tools.r8.D8 \
  --lib "$ANDROID_JAR" \
  --min-api 24 \
  --output "$OUT_DIR/dex" \
  "$OUT_DIR/classes/com/omniaenergy/omnia_energy/"*.class

echo "[5/7] Assembling base module structure for App Bundle..."
unzip -q "$OUT_DIR/proto_base.apk" -d "$OUT_DIR/extracted"
mv "$OUT_DIR/extracted/AndroidManifest.xml" "$OUT_DIR/base_module/manifest/"
mv "$OUT_DIR/extracted/resources.pb" "$OUT_DIR/base_module/"
mv "$OUT_DIR/extracted/res" "$OUT_DIR/base_module/"
mv "$OUT_DIR/extracted/assets" "$OUT_DIR/base_module/"
cp "$OUT_DIR/dex/classes.dex" "$OUT_DIR/base_module/dex/"

(cd "$OUT_DIR/base_module" && zip -q -r "$OUT_DIR/base.zip" .)

RELEASE_AAB="$RELEASE_DIR/OmniaEnergy-v${VERSION}.aab"
LATEST_AAB="$PROJECT_DIR/OmniaEnergy.aab"

echo "[6/7] Building Android App Bundle with bundletool..."
"$JAVA_BIN/java" -jar "$BUNDLETOOL" build-bundle \
  --modules="$OUT_DIR/base.zip" \
  --output="$RELEASE_AAB"

echo "[7/7] Signing AAB with Production Release Key & verifying..."
"$JAVA_BIN/jarsigner" \
  -keystore "$KEYSTORE" \
  -storepass "$STOREPASS" \
  -sigalg SHA384withRSA \
  -digestalg SHA-256 \
  "$RELEASE_AAB" \
  "$KEYALIAS"

"$JAVA_BIN/jarsigner" -verify "$RELEASE_AAB"
"$JAVA_BIN/java" -jar "$BUNDLETOOL" validate --bundle="$RELEASE_AAB"

cp "$RELEASE_AAB" "$LATEST_AAB"

echo "Building test APK set (APKS) for local device verification..."
RELEASE_APKS="$RELEASE_DIR/OmniaEnergy-v${VERSION}.apks"
rm -f "$RELEASE_APKS"
"$JAVA_BIN/java" -jar "$BUNDLETOOL" build-apks \
  --bundle="$RELEASE_AAB" \
  --output="$RELEASE_APKS" \
  --aapt2="$AAPT2" \
  --ks="$KEYSTORE" \
  --ks-pass="pass:$STOREPASS" \
  --ks-key-alias="$KEYALIAS" \
  --key-pass="pass:$STOREPASS"

echo "================================================================="
echo "SUCCESS! Production AAB Built & Signed:"
echo "👉 Bundle: $RELEASE_AAB"
echo "👉 Latest: $LATEST_AAB"
echo "👉 APKs:   $RELEASE_APKS"
echo "================================================================="
