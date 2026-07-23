#!/bin/bash
# Compila l'app nativa SwiftUI (Liquid Glass, macOS 26) in un bundle .app
set -e
cd "$(dirname "$0")"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
swiftc -parse-as-library -sdk "$SDK" -target arm64-apple-macos26.0 \
  -o CostoStampa Sources/Model.swift Sources/App.swift Sources/Views.swift
APP="3D Print Cost.app"
EXE="CostoStampa3D"     # nome interno dell'eseguibile (deve combaciare con CFBundleExecutable)
rm -rf "$APP" CostoStampa3D.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/profiles"
cp CostoStampa "$APP/Contents/MacOS/$EXE"
cp ../app/resources/profiles/*.json "$APP/Contents/Resources/profiles/"
cp ../app/resources/remap.py "$APP/Contents/Resources/"
python3 - "$APP" <<'PY'
import re, sys
p=sys.argv[1]+"/Contents/Resources/remap.py"; s=open(p).read()
s=re.sub(r'MACHINE = .*','import os\nMACHINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles", "machine_H2C_04.json")',s,count=1)
open(p,"w").write(s)
PY
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"
codesign --force --deep -s - "$APP"
echo "Fatto: $APP  —  apri con:  open \"$APP\""
