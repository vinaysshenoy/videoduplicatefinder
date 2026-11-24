#!/usr/bin/env bash
# Builds the macOS GUI as a Native AOT "Video Duplicate Finder.app" bundle,
# mirroring the osx-* steps in .github/workflows/releases.yml.
# Output goes to artifacts/macos/ (gitignored).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

case "$(uname -m)" in
	arm64) RID=osx-arm64 ;;
	x86_64) RID=osx-x64 ;;
	*) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

OUT_DIR="$ROOT/artifacts/macos"
PUBLISH_DIR="$OUT_DIR/outputGUI"
APP="$OUT_DIR/Video Duplicate Finder.app"

rm -rf "$PUBLISH_DIR" "$APP"
mkdir -p "$OUT_DIR"

dotnet publish VDF.GUI/VDF.GUI.csproj -c Release -p:PublishAot=true -r "$RID" -o "$PUBLISH_DIR"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R "$PUBLISH_DIR/." "$APP/Contents/MacOS/"
cp VDF.GUI/Assets/macOS/icon.icns "$APP/Contents/Resources/icon.icns"
cp VDF.GUI/Assets/macOS/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/VDF.GUI"

codesign --force --deep --sign - \
	--entitlements VDF.GUI/Assets/macOS/entitlements.plist \
	"$APP"
codesign --verify --deep --strict "$APP"

echo
echo "Built: $APP"
