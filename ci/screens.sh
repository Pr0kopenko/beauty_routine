#!/bin/bash
# Сборка под симулятор, запуск и скриншоты основных экранов (светлая и тёмная тема).
set -euo pipefail
BUNDLE=com.pr0kopenko.CareTracker
OUT=shots; mkdir -p "$OUT"
TYPE=$(xcrun simctl list devicetypes | grep -oE "iPhone 16 Pro \(com[^)]+\)" | head -1 | sed -E 's/.*\((.*)\)/\1/')
RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
UDID=$(xcrun simctl create shots "$TYPE" "$RUNTIME")
xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b >/dev/null

set -o pipefail
xcodebuild build -project CareTracker.xcodeproj -scheme CareTracker -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO 2>&1 | tee build.log | grep -E "error:|warning: .*/CareTracker/|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" build.log
echo "Скомпилировано Swift-файлов: $(grep -cE '^SwiftCompile normal .*\.swift' build.log || true)"
grep -oE "SwiftCompile normal [^ ]+ [^ ]+\.swift" build.log | awk '{print $NF}' | xargs -n1 basename | sort -u | tr '\n' ' '; echo

xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/CareTracker.app
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 || true

shot() { sleep "${2:-4}"; xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null; echo "снимок $1"; }
launch() { xcrun simctl terminate "$UDID" $BUNDLE 2>/dev/null || true; xcrun simctl launch "$UDID" $BUNDLE "$@" >/dev/null; }

launch; shot 00-welcome
DATA=$(xcrun simctl get_app_container "$UDID" $BUNDLE data)
mkdir -p "$DATA/Library/Application Support/Ritm"
python3 ci/make-sample.py "$DATA/Library/Application Support/Ritm/state.json"

for theme in light dark; do
  xcrun simctl ui "$UDID" appearance $theme
  for tab in today skin products history; do launch -ui.tab $tab; shot "$theme-$tab"; done
  launch -ui.tab today -ui.sheet settings; shot "$theme-settings"
  launch -ui.tab today -ui.sheet mark; shot "$theme-mark"
  launch -ui.tab products -ui.push retinal; shot "$theme-retinoid"
done
xcrun simctl ui "$UDID" appearance light
launch -ui.tab products -ui.push mg; shot light-magnesium
launch -ui.tab products -ui.push retinal -ui.scroll intro; shot light-card-intro 5
launch -ui.tab products -ui.push retinal -ui.scroll compat; shot light-card-compat 5
launch -ui.tab products -ui.push aza -ui.scroll intro; shot light-card-azelaic 5
launch -ui.tab today -ui.sheet add; shot light-add
