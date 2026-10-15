# Ритм кожи — PWA-прототип

Открыть на iPhone: https://pr0kopenko.github.io/beauty_routine/ → «Поделиться» → «На экран „Домой“».

- `index.html`, `styles.css`, `app.js` — интерфейс
- `logic.js` — расписание, статус ретиналя, правила, .ics, словарь INCI (без DOM)
- `sw.js` — офлайн-кэш (меняй `VERSION` при выпуске)
- `tests/logic.test.mjs` — `node --test web/tests/logic.test.mjs`

Деплой: содержимое `web/` (без `tests/` и `package.json`) копируется в ветку `gh-pages`.
