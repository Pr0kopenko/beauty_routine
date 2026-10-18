#!/bin/bash
# Ставит задачу launchd: каждое воскресенье в 12:00 обновить код и переустановить приложение на iPhone
# (бесплатная подпись живёт 7 дней). iPhone должны быть в той же Wi-Fi.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PLIST=~/Library/LaunchAgents/com.ritmkozhi.reinstall.plist
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ritmkozhi.reinstall</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-lc</string>
    <string>cd "$REPO" &amp;&amp; git pull --ff-only &amp;&amp; scripts/install-iphone.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/tmp/ritm-reinstall.log</string>
  <key>StandardErrorPath</key><string>/tmp/ritm-reinstall.log</string>
</dict></plist>
PL
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Еженедельная переустановка включена (лог: /tmp/ritm-reinstall.log)."
