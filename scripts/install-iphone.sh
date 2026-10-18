#!/bin/bash
# Собирает «Ритм кожи» и ставит на подключённые iPhone (кабель или та же Wi-Fi после первого подключения).
# Бесплатный Apple ID: установка живёт 7 дней — запускай раз в неделю (или см. scripts/weekly-reinstall.sh).
# Переменные: TEAM_ID (иначе берём из Xcode), BUNDLE_ID (по умолчанию com.pr0kopenko.CareTracker), DEVICE (UDID; иначе все iPhone).
set -euo pipefail
cd "$(dirname "$0")/.."
TEAM_ID=${TEAM_ID:-$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -o 'teamID = [A-Z0-9]*' | head -1 | awk '{print $3}')}
BUNDLE_ID=${BUNDLE_ID:-com.pr0kopenko.CareTracker}
[ -n "$TEAM_ID" ] || { echo "Нет команды разработчика: добавь Apple ID в Xcode → Settings → Accounts"; exit 1; }

if [ -n "${DEVICE:-}" ]; then DEVICES="$DEVICE"
else
  xcrun devicectl list devices --json-output /tmp/ritm-devices.json >/dev/null
  DEVICES=$(python3 -c "
import json; d=json.load(open('/tmp/ritm-devices.json'))
for x in d['result']['devices']:
    hp=x.get('hardwareProperties',{}); cp=x.get('connectionProperties',{})
    if hp.get('platform')=='iOS' and cp.get('tunnelState')!='unavailable': print(hp.get('udid') or x['identifier'])")
fi
[ -n "$DEVICES" ] || { echo "iPhone не найден. Подключи кабелем, разблокируй и нажми «Доверять»."; exit 1; }

for UDID in $DEVICES; do
  echo "→ Сборка для $UDID"
  xcodebuild build -project CareTracker.xcodeproj -scheme CareTracker -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/device -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_STYLE=Automatic -quiet
  APP=build/device/Build/Products/Debug-iphoneos/CareTracker.app
  xcrun devicectl device install app --device "$UDID" "$APP"
  xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || echo "Открой приложение на iPhone (при первом запуске: Настройки → Основные → VPN и управление устройством → Доверять)."
done
echo "Готово: установлено на $(echo "$DEVICES" | wc -w | tr -d ' ') iPhone."
