// Генерирует запасной календарь со временем по умолчанию: node web/gen-ics.mjs
import { writeFileSync } from 'node:fs';
import { buildIcs, seedState } from './logic.js';
const r = seedState().reminders;
writeFileSync(new URL('./ritm-kozhi-default.ics', import.meta.url), buildIcs(r, '2026-10-16', 'https://pr0kopenko.github.io/beauty_routine/'));
