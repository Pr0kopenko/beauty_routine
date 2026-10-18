#!/bin/bash
# Автообновление: каждые 10 минут смотрит GitHub. Если в main есть новые правки — забирает их
# и ставит приложение на iPhone в той же Wi-Fi. Раз в неделю переустанавливает в любом случае
# (бесплатная подпись Apple живёт 7 дней). Включение: scripts/auto-update.sh --install
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$HOME/Library/Application Support/RitmKozhi/last-install"
LOG=/tmp/ritm-auto-update.log

if [ "${1:-}" = "--install" ]; then
  PLIST=~/Library/LaunchAgents/com.ritmkozhi.autoupdate.plist
  launchctl unload ~/Library/LaunchAgents/com.ritmkozhi.reinstall.plist 2>/dev/null || true
  cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ritmkozhi.autoupdate</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-lc</string><string>"$REPO/scripts/auto-update.sh"</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict></plist>
PL
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
  echo "Автообновление включено: проверка каждые 10 минут, лог $LOG"
  exit 0
fi

cd "$REPO" || exit 1
mkdir -p "$(dirname "$STAMP")"
git fetch -q origin main || exit 0
NEW=$(git rev-parse origin/main); CUR=$(git rev-parse HEAD)
LAST=$(cat "$STAMP" 2>/dev/null | awk '{print $1}'); LAST_AT=$(cat "$STAMP" 2>/dev/null | awk '{print $2}')
AGE=$(( $(date +%s) - ${LAST_AT:-0} ))
if [ "$NEW" = "$CUR" ] && [ "$LAST" = "$CUR" ] && [ $AGE -lt $((6 * 24 * 3600)) ]; then exit 0; fi

echo "$(date '+%F %T') обновление: $CUR → $NEW"
git merge -q --ff-only origin/main || { echo "Не получилось обновить код (локальные правки?)"; exit 1; }
if scripts/install-iphone.sh; then
  echo "$(git rev-parse HEAD) $(date +%s)" > "$STAMP"
  osascript -e 'display notification "Новая версия установлена на iPhone" with title "Ритм кожи"' 2>/dev/null || true
else
  echo "Установка не удалась (телефоны не в сети?) — попробую через 10 минут"
fi
