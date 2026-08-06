#!/bin/bash
# Compila l'app nativa SwiftUI (Liquid Glass, macOS 26) in un bundle .app
set -e
cd "$(dirname "$0")"
# SDK: Command Line Tools se presenti (Mac di sviluppo), altrimenti xcrun (runner CI con Xcode)
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
[ -d "$SDK" ] || SDK="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -parse-as-library -sdk "$SDK" -target arm64-apple-macos26.0 \
  -o CostoStampa Sources/*.swift
APP="3D Print Cost.app"
EXE="CostoStampa3D"     # nome interno dell'eseguibile (deve combaciare con CFBundleExecutable)
# il bundle si assembla e si firma in una cartella temporanea FUORI da iCloud:
# dentro cartelle sincronizzate (Desktop/Documenti) la firma fallisce a caso
# con "resource fork, Finder information, or similar detritus not allowed"
TMPAPP="$(mktemp -d)/$APP"
mkdir -p "$TMPAPP/Contents/MacOS" "$TMPAPP/Contents/Resources/profiles"
cp CostoStampa "$TMPAPP/Contents/MacOS/$EXE"
cp ../app/resources/profiles/*.json "$TMPAPP/Contents/Resources/profiles/"
cp ../app/resources/remap.py "$TMPAPP/Contents/Resources/"
python3 - "$TMPAPP" <<'PY'
import re, sys
p=sys.argv[1]+"/Contents/Resources/remap.py"; s=open(p).read()
s=re.sub(r'MACHINE = .*','import os\nMACHINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles", "machine_H2C_04.json")',s,count=1)
open(p,"w").write(s)
PY
cp Info.plist "$TMPAPP/Contents/Info.plist"
cp AppIcon.icns "$TMPAPP/Contents/Resources/AppIcon.icns"

xattr -cr "$TMPAPP"
codesign --force --deep -s - "$TMPAPP"
rm -rf "$APP" CostoStampa3D.app
mv "$TMPAPP" "$APP"
echo "Fatto: $APP  —  apri con:  open \"$APP\""
