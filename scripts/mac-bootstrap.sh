#!/bin/bash
# Готовит Мак к сборке «Ритма кожи»: Xcode, симулятор, Node (для сервера). Можно запускать повторно.
set -uo pipefail
ok() { echo "✓ $*"; }; todo() { echo "• $*"; }

if [ ! -d /Applications/Xcode.app ]; then
  todo "Xcode не установлен. Открываю App Store — нажми «Загрузить» (около 10 ГБ)."
  open "macappstore://apps.apple.com/app/xcode/id497799835"; exit 1
fi
if [ "$(xcode-select -p 2>/dev/null)" != "/Applications/Xcode.app/Contents/Developer" ]; then
  todo "Переключаю инструменты на Xcode (попросит пароль от Мака)"
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi
sudo xcodebuild -license accept 2>/dev/null || true
xcodebuild -runFirstLaunch >/dev/null 2>&1 || true
ok "$(xcodebuild -version | head -1)"

if ! xcrun simctl list runtimes | grep -q "iOS"; then
  todo "Скачиваю симулятор iOS (несколько ГБ)…"
  xcodebuild -downloadPlatform iOS
fi
ok "Симулятор: $(xcrun simctl list runtimes | grep -o 'iOS [0-9.]*' | tail -1)"

if ! command -v node >/dev/null; then
  if command -v brew >/dev/null; then brew install node
  else
    todo "Ставлю Node.js (нужен только для сервера распознавания)…"
    curl -fsSL "https://nodejs.org/dist/v22.11.0/node-v22.11.0.pkg" -o /tmp/node.pkg && sudo installer -pkg /tmp/node.pkg -target /
  fi
fi
command -v node >/dev/null && ok "Node $(node -v)"

TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -o 'teamID = [A-Z0-9]*' | head -1 | awk '{print $3}')
if [ -n "${TEAM:-}" ]; then ok "Команда разработчика: $TEAM"
else todo "В Xcode нет Apple ID: Xcode → Settings → Accounts → «+» → Apple ID (пароль вводит владелица)"; fi
echo "Готово."
