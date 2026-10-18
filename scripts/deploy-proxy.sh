#!/bin/bash
# Поднимает сервер распознавания на Cloudflare (бесплатно) и печатает адрес и инвайт-коды для приложения.
# Владелица один раз: входит в Cloudflare в браузере (кнопка Allow) и вставляет ключ OpenAI.
set -euo pipefail
cd "$(dirname "$0")/../proxy"
W="npx --yes wrangler@4"
$W whoami >/dev/null 2>&1 || $W login

if ! grep -q '^\[\[kv_namespaces\]\]' wrangler.toml; then
  ID=$($W kv namespace create USAGE 2>&1 | grep -oE '[a-f0-9]{32}' | head -1 || true)
  if [ -n "$ID" ]; then printf '\n[[kv_namespaces]]\nbinding = "USAGE"\nid = "%s"\n' "$ID" >> wrangler.toml; fi
fi

if [ -n "${OPENAI_API_KEY:-}" ]; then echo "$OPENAI_API_KEY" | $W secret put OPENAI_API_KEY
else echo "Вставь ключ OpenAI (sk-…) и нажми Enter:"; $W secret put OPENAI_API_KEY; fi
[ -n "${ANTHROPIC_API_KEY:-}" ] && echo "$ANTHROPIC_API_KEY" | $W secret put ANTHROPIC_API_KEY

CODES=${INVITES:-"$(openssl rand -hex 4),$(openssl rand -hex 4)"}
echo "$CODES" | $W secret put INVITES
OUT=$($W deploy 2>&1); echo "$OUT" | tail -5
URL=$(echo "$OUT" | grep -o 'https://[a-z0-9.-]*workers.dev' | head -1)
echo
echo "Адрес сервера: $URL"
echo "Инвайт-коды (по одному на телефон): $CODES"
[ -n "$URL" ] && curl -s "$URL" && echo
echo "В приложении: Настройки → Распознавание → «Инвайт-код» → адрес и код."
