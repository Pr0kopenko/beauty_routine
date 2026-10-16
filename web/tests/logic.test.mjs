import test from 'node:test';
import assert from 'node:assert/strict';
import * as L from '../logic.js';

const mk = (over = {}) => ({ ...L.seedState(), onboarded: true, ...over });
const mark = (itemId, day, slot = 'evening') => ({ id: L.uid(), itemId, day, slot, at: day + 'T22:00' });

test('dayKey: граница дня в 04:00', () => {
  assert.equal(L.dayKey(new Date(2026, 9, 16, 0, 40)), '2026-10-15');
  assert.equal(L.dayKey(new Date(2026, 9, 16, 4, 0)), '2026-10-16');
  assert.equal(L.dayKey(new Date(2026, 9, 16, 23, 59)), '2026-10-16');
});

test('addDays/daysBetween через переход на зимнее время', () => {
  assert.equal(L.addDays('2026-10-24', 3), '2026-10-27');
  assert.equal(L.daysBetween('2026-10-24', '2026-10-27'), 3);
  assert.equal(L.addDays('2026-12-30', 3), '2027-01-02');
});

test('16 октября 2026 — пятница', () => {
  assert.equal(L.weekday('2026-10-16'), 5);
  assert.equal(L.fmtLong('2026-10-16'), 'Пятница, 16 октября');
});

test('статус ретиналя: 2 раза в неделю (интервал 3 дня)', () => {
  const s = mk();
  const item = s.items.find((i) => i.id === 'retinal');
  assert.equal(L.intervalStatus(item, [], '2026-10-16').state, 'notStarted');
  const e = [mark('retinal', '2026-10-14')];
  const at = (d) => L.intervalStatus(item, e, d);
  assert.equal(at('2026-10-14').state, 'done');
  assert.equal(at('2026-10-14').next, '2026-10-17');
  assert.equal(at('2026-10-15').state, 'resting');
  assert.equal(at('2026-10-16').state, 'resting');
  assert.equal(at('2026-10-16').next, '2026-10-17');
  assert.equal(at('2026-10-17').state, 'today');
  assert.equal(at('2026-10-19').state, 'today');
  assert.equal(at('2026-10-20').state, 'overdue');
  assert.equal(at('2026-10-20').since, 6);
});

test('статус: смена частоты меняет только будущее', () => {
  const s = mk();
  const item = { ...s.items.find((i) => i.id === 'retinal'), schedule: { type: 'interval', freq: '1w' } };
  const e = [mark('retinal', '2026-10-14')];
  assert.equal(L.intervalStatus(item, e, '2026-10-17').state, 'resting');
  assert.equal(L.intervalStatus(item, e, '2026-10-17').next, '2026-10-21');
});

test('статус: отметки в будущем не влияют на «сегодня», пропуски не считаются', () => {
  const s = mk();
  const item = s.items.find((i) => i.id === 'retinal');
  const e = [mark('retinal', '2026-10-10'), { ...mark('retinal', '2026-10-15'), skipped: true }, mark('retinal', '2026-10-20')];
  const st = L.intervalStatus(item, e, '2026-10-16');
  assert.equal(st.last, '2026-10-10');
  assert.equal(st.state, 'overdue');
});

test('правила: ретиналь раньше интервала — подсказка', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-14')] });
  const hints = L.checkMark({ itemId: 'retinal', day: '2026-10-15', slot: 'evening' }, s);
  assert.ok(hints.some((h) => h.rule === 'retinoid-interval'));
  assert.equal(L.checkMark({ itemId: 'retinal', day: '2026-10-17', slot: 'evening' }, s).length, 0);
});

test('правила: отметка задним числом, ломающая интервал с более поздней', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-17')] });
  const hints = L.checkMark({ itemId: 'retinal', day: '2026-10-15', slot: 'evening' }, s);
  assert.ok(hints.some((h) => h.rule === 'retinoid-interval'));
});

test('правила: ретиналь и азелаиновая в один вечер — в обе стороны', () => {
  const s1 = mk({ entries: [mark('aza-cream', '2026-10-17')] });
  assert.ok(L.checkMark({ itemId: 'retinal', day: '2026-10-17', slot: 'evening' }, s1).some((h) => h.rule === 'retinoid-azelaic'));
  const s2 = mk({ entries: [mark('retinal', '2026-10-17')] });
  assert.ok(L.checkMark({ itemId: 'aza-serum', day: '2026-10-17', slot: 'evening' }, s2).some((h) => h.rule === 'retinoid-azelaic'));
  assert.equal(L.checkMark({ itemId: 'aza-serum', day: '2026-10-17', slot: 'morning' }, s2).length, 0);
});

test('правила: выключенное правило молчит', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-17')] });
  s.rules['retinoid-azelaic'] = false;
  assert.equal(L.checkMark({ itemId: 'aza-serum', day: '2026-10-17', slot: 'evening' }, s).length, 0);
});

test('правила: кислоты — соседний вечер с ретиналем и лимит 2 в неделю', () => {
  const s = mk();
  s.items.push({ id: 'toner', name: 'Тонер с гликолевой', actives: ['aha'], block: 'optional', schedule: { type: 'asneeded' }, archived: false });
  s.entries.push(mark('retinal', '2026-10-17'));
  assert.ok(!L.checkMark({ itemId: 'toner', day: '2026-10-18', slot: 'evening' }, s).some((h) => h.rule === 'retinoid-acids-adjacent'), 'соседние дни по умолчанию можно');
  s.rules['retinoid-acids-adjacent'] = true;
  assert.ok(L.checkMark({ itemId: 'toner', day: '2026-10-18', slot: 'evening' }, s).some((h) => h.rule === 'retinoid-acids-adjacent'));
  s.entries.push(mark('toner', '2026-10-10'), mark('toner', '2026-10-12'));
  assert.ok(L.checkMark({ itemId: 'toner', day: '2026-10-14', slot: 'evening' }, s).some((h) => h.rule === 'acids-weekly'));
  assert.ok(!L.checkMark({ itemId: 'toner', day: '2026-10-20', slot: 'evening' }, s).some((h) => h.rule === 'acids-weekly'));
});

test('правила: ретиналь утром', () => {
  const s = mk();
  assert.ok(L.checkMark({ itemId: 'retinal', day: '2026-10-17', slot: 'morning' }, s).some((h) => h.rule === 'retinoid-evening'));
});

test('план: вечер ретиналя переносит азелаиновую в «По желанию» с пометкой', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-14')] });
  s.items.find((i) => i.id === 'aza-serum').block = 'evening';
  const p = L.planForDay(s, '2026-10-17');
  assert.equal(p.blocks.evening[0].item.id, 'retinal');
  const az = p.blocks.optional.find((r) => r.item.id === 'aza-serum');
  assert.ok(az && az.deferred);
});

test('план: в день отдыха ретиналь в «По желанию», азелаиновая на своём месте', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-14')] });
  s.items.find((i) => i.id === 'aza-serum').block = 'evening';
  const p = L.planForDay(s, '2026-10-15');
  assert.ok(p.blocks.evening.some((r) => r.item.id === 'aza-serum'));
  assert.ok(p.blocks.optional.find((r) => r.item.id === 'retinal').deferred);
});

test('план: SPF-акцент на утро после ретиналя', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-17')] });
  const p = L.planForDay(s, '2026-10-18');
  assert.ok(p.blocks.morning.find((r) => r.item.id === 'spf').accent);
  assert.ok(!L.planForDay(s, '2026-10-19').blocks.morning.find((r) => r.item.id === 'spf').accent);
});

test('ics: будни/выходные, вечер, разовый сдвиг с EXDATE', () => {
  const r = { morning: { weekdays: '07:45', weekend: '09:30' }, evening: '22:00', overrides: { '2026-10-16': '07:15' } };
  const ics = L.buildIcs(r, '2026-10-15', 'https://example.com/');
  assert.match(ics, /BEGIN:VCALENDAR/);
  assert.match(ics, /DTSTART:20261015T074500/);
  assert.match(ics, /BYDAY=MO,TU,WE,TH,FR/);
  assert.match(ics, /DTSTART:20261017T093000/);
  assert.match(ics, /EXDATE:20261016T074500/);
  assert.match(ics, /DTSTART:20261016T071500/);
  assert.match(ics, /DTSTART:20261015T220000/);
  assert.equal((ics.match(/BEGIN:VALARM/g) || []).length, 4);
  assert.ok(ics.split('\r\n').every((l) => l.length <= 75));
});

test('INCI: находит активы в составе', () => {
  const r = L.detectActives('Aqua, Glycolic Acid, Butylene Glycol, Niacinamide, Panthenol, Retinal, Palmitoyl Tripeptide-1, Citric Acid');
  assert.deepEqual(new Set(r.actives), new Set(['aha', 'niacinamide', 'retinoid', 'peptides']));
  assert.ok(!L.detectActives('Water, Glycerin, Citric Acid, Xanthan Gum, Sodium Benzoate, Potassium Sorbate, Parfum, Linalool, Limonene, Tocopherol').actives.includes('aha'));
  assert.deepEqual(L.detectActives('Вода, азелаиновая кислота').actives, ['azelaic']);
});

test('импорт: валидирует и дополняет', () => {
  assert.throws(() => L.validateImport({ foo: 1 }));
  const s = L.validateImport({ items: [], entries: [], rules: { 'acids-weekly': false } });
  assert.equal(s.rules['acids-weekly'], false);
  assert.equal(s.rules['retinoid-azelaic'], true);
});

test('plural', () => {
  assert.equal(L.daysWord(1), '1\u00a0день');
  assert.equal(L.daysWord(3), '3\u00a0дня');
  assert.equal(L.daysWord(11), '11\u00a0дней');
  assert.equal(L.daysWord(22), '22\u00a0дня');
});

const prod = (id, actives, extra = {}) => ({ id, name: id, actives, block: 'optional', schedule: { type: 'asneeded' }, archived: false, type: 'serum', ...extra });

test('правила v2: БПО окисляет ретинол, но не адапален', () => {
  const s = mk({ items: [prod('bpo', ['bpo']), prod('rol', ['retinoid'], { retinoidForm: 'retinol' }), prod('ada', ['retinoid'], { retinoidForm: 'adapalene' })], entries: [mark('bpo', '2026-10-17')] });
  assert.ok(L.checkMark({ itemId: 'rol', day: '2026-10-17', slot: 'evening' }, s).some((h) => h.rule === 'retinoid-bpo'));
  assert.ok(!L.checkMark({ itemId: 'ada', day: '2026-10-17', slot: 'evening' }, s).some((h) => h.rule === 'retinoid-bpo'));
  assert.ok(!L.checkMark({ itemId: 'rol', day: '2026-10-17', slot: 'morning' }, s).some((h) => h.rule === 'retinoid-bpo'), 'утро и вечер — можно');
});

test('правила v2: витамин C, один эксфолиант, медные пептиды', () => {
  const s = mk({ items: [prod('c', ['vitc']), prod('ret', ['retinoid'], { retinoidForm: 'retinal' }), prod('aha', ['aha']), prod('scrub', ['exfoliant']), prod('cu', ['copper'])], entries: [mark('ret', '2026-10-17'), mark('aha', '2026-10-15', 'morning')] });
  assert.ok(L.checkMark({ itemId: 'c', day: '2026-10-17', slot: 'evening' }, s).some((h) => h.rule === 'vitc-retinoid'));
  assert.ok(!L.checkMark({ itemId: 'c', day: '2026-10-17', slot: 'morning' }, s).length);
  assert.ok(L.checkMark({ itemId: 'scrub', day: '2026-10-15', slot: 'evening' }, s).some((h) => h.rule === 'one-exfoliant'));
  assert.ok(L.checkMark({ itemId: 'cu', day: '2026-10-15', slot: 'morning' }, s).some((h) => h.rule === 'copper-acids'));
});

test('этапы: через день не чаще 4 раз в неделю, 4–5 раз — без интервала', () => {
  const s = mk();
  const ret = { ...s.items.find((i) => i.id === 'retinal'), schedule: { type: 'interval', freq: 'eod' } };
  const e = ['2026-10-10', '2026-10-12', '2026-10-14'].map((d) => mark('retinal', d));
  assert.equal(L.intervalStatus(ret, e, '2026-10-15').state, 'resting');
  assert.equal(L.intervalStatus(ret, e, '2026-10-16').state, 'today');
  const r5 = { ...ret, schedule: { type: 'interval', freq: '5w' } };
  const e5 = ['2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16'].map((d) => mark('retinal', d));
  assert.equal(L.intervalStatus(r5, e5, '2026-10-17').state, 'resting', 'лимит 5 в неделю');
  assert.equal(L.intervalStatus(r5, e5, '2026-10-17').next, '2026-10-19');
});

test('пауза по реакции: средне — 3 дня, сильно — пока не пройдёт', () => {
  const s = mk({ entries: [mark('retinal', '2026-10-10')] });
  const ret = s.items.find((i) => i.id === 'retinal');
  s.diary = { '2026-10-15': { reactions: { redness: 2 } } };
  assert.equal(L.intervalStatus(ret, s.entries, '2026-10-16', s).state, 'paused');
  assert.equal(L.intervalStatus(ret, s.entries, '2026-10-18', s).state, 'overdue');
  s.diary = { '2026-10-15': { reactions: { burning: 3 } } };
  assert.equal(L.intervalStatus(ret, s.entries, '2026-10-17', s).state, 'paused');
  s.diary['2026-10-17'] = { reactions: { burning: 0, redness: 0 } };
  assert.notEqual(L.intervalStatus(ret, s.entries, '2026-10-17', s).state, 'paused');
  s.diary = { '2026-10-15': { reactions: { breakouts: 3 } } };
  assert.notEqual(L.intervalStatus(ret, s.entries, '2026-10-16', s).state, 'paused', 'высыпания — не раздражение');
  s.diary = {}; s.settings.pregnancy = true;
  assert.equal(L.intervalStatus(ret, s.entries, '2026-10-16', s).state, 'blocked');
});

test('совет: шаг вверх после 2 недель без реакций, шаг вниз при реакции', () => {
  const s = mk();
  const ret = s.items.find((i) => i.id === 'retinal'); ret.retinoidForm = 'retinal'; ret.schedule = { type: 'interval', freq: '2w', since: '2026-10-01' };
  s.entries = ['2026-10-01', '2026-10-05', '2026-10-09', '2026-10-13'].map((d) => mark('retinal', d));
  const up = L.retinoidAdvice(ret, s, '2026-10-16');
  assert.equal(up.kind, 'up'); assert.equal(up.to, 'eod');
  assert.equal(L.retinoidAdvice(ret, s, '2026-10-10'), null, 'рано');
  ret.schedule.freq = 'eod'; s.diary = { '2026-10-15': { reactions: { dryness: 2 } } };
  const down = L.retinoidAdvice(ret, s, '2026-10-16');
  assert.equal(down.kind, 'down'); assert.equal(down.to, '2w');
});

test('миграция v1 → v2', () => {
  const old = { items: [{ id: 'retinal', name: 'Ретиналь', actives: ['retinoid'], block: 'evening', schedule: { type: 'interval', freq: '2w' } }, { id: 'm', name: 'Магний', actives: ['supplement'], block: 'supplements' }], entries: [], rules: { 'retinoid-acids-adjacent': true }, version: 1 };
  const s = L.validateImport(old);
  assert.equal(s.items[0].retinoidForm, 'retinal');
  assert.equal(s.items[1].type, 'supplement');
  assert.equal(s.rules['retinoid-acids-adjacent'], false);
  assert.deepEqual(s.diary, {});
});
