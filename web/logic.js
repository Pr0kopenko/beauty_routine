// Чистая логика «Ритма кожи»: дни, статус ретиналя, правила, план дня, .ics, словарь INCI.
// Без DOM — тестируется в Node (web/tests/logic.test.mjs).

export const SCHEMA_VERSION = 1;
export const DAY_START_HOUR = 4; // день ухода заканчивается в 04:00

// ---------- даты ----------

const pad = (n) => String(n).padStart(2, '0');

/** Ключ дня ухода 'YYYY-MM-DD' в местном времени, с границей дня в 04:00. */
export function dayKey(date = new Date()) {
  const d = new Date(date.getTime());
  if (d.getHours() < DAY_START_HOUR) d.setDate(d.getDate() - 1);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** Полдень дня ключа — безопасно для арифметики с переходом на летнее время. */
export function keyToDate(key) {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d, 12, 0, 0);
}

export function addDays(key, n) {
  const d = keyToDate(key);
  d.setDate(d.getDate() + n);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function daysBetween(fromKey, toKey) {
  return Math.round((keyToDate(toKey) - keyToDate(fromKey)) / 86400000);
}

const WEEKDAYS_SHORT = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const WEEKDAYS_ACC = ['в воскресенье', 'в понедельник', 'во вторник', 'в среду', 'в четверг', 'в пятницу', 'в субботу'];
const WEEKDAYS_FULL = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
const MONTHS_GEN = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
export const MONTHS_NOM = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

export const weekday = (key) => keyToDate(key).getDay();
export const fmtShort = (key) => { const d = keyToDate(key); return `${WEEKDAYS_SHORT[d.getDay()]}, ${d.getDate()} ${MONTHS_GEN[d.getMonth()].slice(0, 3)}`; };
export const fmtLong = (key) => { const d = keyToDate(key); return `${WEEKDAYS_FULL[d.getDay()]}, ${d.getDate()} ${MONTHS_GEN[d.getMonth()]}`; };
export const fmtDayMonth = (key) => { const d = keyToDate(key); return `${d.getDate()} ${MONTHS_GEN[d.getMonth()]}`; };

/** «сегодня», «завтра», «в пятницу» (в пределах недели) или «пн, 20 окт». */
export function whenWord(key, today) {
  const diff = daysBetween(today, key);
  if (diff === 0) return 'сегодня';
  if (diff === 1) return 'завтра';
  if (diff === -1) return 'вчера';
  if (diff > 1 && diff < 7) return WEEKDAYS_ACC[weekday(key)];
  return fmtShort(key);
}

export function plural(n, one, few, many) {
  const a = Math.abs(n) % 100, b = a % 10;
  if (a > 10 && a < 20) return many;
  if (b > 1 && b < 5) return few;
  if (b === 1) return one;
  return many;
}
export const daysWord = (n) => `${n} ${plural(n, 'день', 'дня', 'дней')}`;

// ---------- активы и частоты ----------

export const ACTIVES = {
  retinoid: { name: 'Ретиноид', color: 'ret' },
  aha: { name: 'AHA', color: 'acid' },
  bha: { name: 'BHA', color: 'acid' },
  pha: { name: 'PHA', color: 'acid' },
  azelaic: { name: 'Азелаиновая кислота', color: 'az' },
  niacinamide: { name: 'Ниацинамид', color: 'ni' },
  vitc: { name: 'Витамин C', color: 'vc' },
  peptides: { name: 'Пептиды', color: 'pep' },
  bpo: { name: 'Бензоилпероксид', color: 'acid' },
  spf: { name: 'SPF', color: 'spf' },
  supplement: { name: 'Добавка', color: 'sup' },
};
export const ACID_GROUP = ['aha', 'bha', 'pha']; // азелаиновая сюда не входит

export const FREQUENCIES = {
  '1w': { label: '1 раз в неделю', minDays: 7 },
  '2w': { label: '2 раза в неделю', minDays: 3 },
  eod: { label: 'Через день', minDays: 2 },
};

const has = (item, active) => item.actives.includes(active);
const hasAcid = (item) => item.actives.some((a) => ACID_GROUP.includes(a));
export const isRetinoid = (item) => has(item, 'retinoid');

// ---------- стартовые данные ----------

export function seedState() {
  const items = [
    { id: 'retinal', name: 'Ретиналь', note: 'корейский', actives: ['retinoid'], block: 'evening', schedule: { type: 'interval', freq: '2w' } },
    { id: 'aravia', name: 'Пептидная сыворотка Aravia', actives: ['peptides'], block: 'optional' },
    { id: 'aza-serum', name: 'Сыворотка с азелаиновой кислотой', actives: ['azelaic'], block: 'optional' },
    { id: 'aza-cream', name: 'Крем с азелаиновой кислотой', actives: ['azelaic'], block: 'optional' },
    { id: 'niac', name: 'Сыворотка с ниацинамидом', actives: ['niacinamide'], block: 'optional' },
    { id: 'spf', name: 'SPF Skin1004', actives: ['spf'], block: 'morning' },
    { id: 'eye-patch', name: 'Роллер-патчи для глаз', actives: [], block: 'optional' },
    { id: 'magnesium', name: 'Магний', actives: ['supplement'], block: 'supplements', dose: '' },
  ].map((it) => ({ archived: false, schedule: { type: 'daily' }, ...it }));
  items.find((i) => i.id === 'aravia').schedule = { type: 'asneeded' };
  for (const id of ['aza-serum', 'aza-cream', 'niac', 'eye-patch']) items.find((i) => i.id === id).schedule = { type: 'asneeded' };
  return {
    version: SCHEMA_VERSION,
    onboarded: false,
    items,
    entries: [],
    rules: Object.fromEntries(RULES.map((r) => [r.id, r.defaultOn])),
    reminders: {
      morning: { weekdays: '07:45', weekend: '09:30' }, // пн–пт / сб–вс
      evening: '22:00',
      overrides: {}, // { 'YYYY-MM-DD': '07:15' } — разовый сдвиг утра
    },
    lastBackupAt: null,
  };
}

// ---------- статус ретиналя ----------

export function lastDayOf(itemId, entries, beforeOrOn) {
  let last = null;
  for (const e of entries) {
    if (e.itemId !== itemId || e.skipped) continue;
    if (beforeOrOn && e.day > beforeOrOn) continue;
    if (!last || e.day > last) last = e.day;
  }
  return last;
}

/**
 * Состояния: notStarted · done · resting · today · overdue.
 * today — интервал прошёл не больше чем на 2 дня; overdue — дольше.
 */
export function intervalStatus(item, entries, today) {
  const freq = FREQUENCIES[item.schedule?.freq] || FREQUENCIES['2w'];
  const minDays = freq.minDays;
  const last = lastDayOf(item.id, entries, today);
  if (!last) return { state: 'notStarted', minDays, last: null, since: null, next: today };
  const since = daysBetween(last, today);
  if (since === 0) {
    const prev = lastDayOf(item.id, entries.filter((e) => !(e.itemId === item.id && e.day === today)), today);
    return { state: 'done', minDays, last, since, next: addDays(today, minDays), prev };
  }
  const next = addDays(last, minDays);
  if (since < minDays) return { state: 'resting', minDays, last, since, next };
  if (since <= minDays + 2) return { state: 'today', minDays, last, since, next: today };
  return { state: 'overdue', minDays, last, since, next: today };
}

export function statusText(item, st, today) {
  const n = item.name;
  switch (st.state) {
    case 'notStarted': return { title: `${n}: можно начать сегодня`, sub: 'Отметь, когда нанесёшь, — дальше посчитаю сама.' };
    case 'done': return { title: `${n} сделан`, sub: `Следующий — ${whenWord(st.next, today)}, ${fmtDayMonth(st.next)}.` };
    case 'resting': return { title: `${n} отдыхает`, sub: `Был ${whenWord(st.last, today)}. Следующий — ${whenWord(st.next, today)} вечером.` };
    case 'today': return { title: `Сегодня вечер — ${n.toLowerCase()}`, sub: `Прошло ${daysWord(st.since)} — можно.` };
    case 'overdue': return { title: `${n}а не было ${daysWord(st.since)}`, sub: 'Можно сегодня вечером.' };
    default: return { title: n, sub: '' };
  }
}

/** Детали для карточки статуса на «Сегодня» (заголовок экрана уже даёт ответ). */
export function heroText(item, st, today) {
  const freq = FREQUENCIES[item.schedule?.freq]?.label.toLowerCase() || '';
  switch (st.state) {
    case 'notStarted': return { title: 'Первый раз — когда будешь готова', sub: 'Нанеси вечером и отметь — дальше посчитаю сама.' };
    case 'done': return { title: 'Сделано сегодня', sub: `Следующий — ${whenWord(st.next, today)}, ${fmtDayMonth(st.next)}.` };
    case 'resting': { const left = st.minDays - st.since; return { title: `Ещё ${daysWord(left)} отдыха`, sub: `Был ${fmtShort(st.last)}. Можно с ${fmtShort(st.next)}.` }; }
    case 'today': return { title: `Прошло ${daysWord(st.since)} — можно`, sub: `Последний раз ${fmtShort(st.last)} · ${freq}.` };
    case 'overdue': return { title: `Прошло ${daysWord(st.since)} — пора`, sub: `Последний раз ${fmtShort(st.last)} · ${freq}.` };
    default: return { title: item.name, sub: '' };
  }
}

// ---------- правила ----------

export const RULES = [
  { id: 'retinoid-interval', text: 'Ретиналь не чаще выбранной частоты', sub: 'сейчас — по частоте в карточке ретиналя', defaultOn: true },
  { id: 'retinoid-azelaic', text: 'Ретиналь и азелаиновая — разные вечера', sub: 'пока вводишь ретиналь', defaultOn: true },
  { id: 'retinoid-acids', text: 'Ретиноид и AHA/BHA — разные вечера', sub: '', defaultOn: true },
  { id: 'retinoid-acids-adjacent', text: 'Ретиноид и AHA/BHA — не в соседние вечера', sub: 'день отдыха между ними', defaultOn: true },
  { id: 'acids-weekly', text: 'Кислоты AHA/BHA — до 2 раз в неделю', sub: '', defaultOn: true },
  { id: 'retinoid-evening', text: 'Ретиноид — только вечером', sub: '', defaultOn: true },
  { id: 'retinoid-bpo', text: 'Ретиноид и бензоилпероксид — не вместе', sub: '', defaultOn: true },
  { id: 'spf-after', text: 'SPF утром после ретиналя или кислот', sub: 'выделю SPF на утро', defaultOn: true },
];

/** Отметки дня (без пропусков), кроме кандидата. */
function dayItems(day, items, entries, slot) {
  const ids = new Set(entries.filter((e) => e.day === day && !e.skipped && (!slot || e.slot === slot)).map((e) => e.itemId));
  return items.filter((i) => ids.has(i.id));
}

/**
 * Подсказки для кандидата {itemId, day, slot}. Возвращает [{rule, text}].
 * Подсказка не запрещает отметку.
 */
export function checkMark(candidate, state) {
  const { items, entries, rules } = state;
  const item = items.find((i) => i.id === candidate.itemId);
  if (!item) return [];
  const on = (id) => rules[id] !== false;
  const { day, slot } = candidate;
  const others = entries.filter((e) => !(e.itemId === item.id && e.day === day));
  const sameEvening = slot === 'evening' ? dayItems(day, items, others, 'evening') : [];
  const sameDayAll = dayItems(day, items, others);
  const out = [];
  const nameOf = (list) => list.map((i) => i.name.toLowerCase()).join(', ');

  if (isRetinoid(item)) {
    if (on('retinoid-interval')) {
      const minDays = (FREQUENCIES[item.schedule?.freq] || FREQUENCIES['2w']).minDays;
      const prev = lastDayOf(item.id, others, day);
      const nextAfter = entries.filter((e) => e.itemId === item.id && !e.skipped && e.day > day).map((e) => e.day).sort()[0];
      if (prev && daysBetween(prev, day) < minDays) {
        out.push({ rule: 'retinoid-interval', text: `До этого ретиналь был ${fmtShort(prev)} — всего ${daysWord(daysBetween(prev, day))} назад, а по частоте нужно ${daysWord(minDays)}. Можно с ${fmtShort(addDays(prev, minDays))}.` });
      } else if (nextAfter && daysBetween(day, nextAfter) < minDays) {
        out.push({ rule: 'retinoid-interval', text: `Через ${daysWord(daysBetween(day, nextAfter))} уже отмечен ретиналь — интервал будет короче ${daysWord(minDays)}.` });
      }
    }
    if (on('retinoid-evening') && slot === 'morning') out.push({ rule: 'retinoid-evening', text: 'Ретиналь лучше наносить вечером: на свету он разрушается.' });
    const az = sameEvening.filter((i) => has(i, 'azelaic'));
    if (on('retinoid-azelaic') && az.length) out.push({ rule: 'retinoid-azelaic', text: `Сегодня вечером уже была ${nameOf(az)}. Пока вводишь ретиналь, их лучше разнести по разным вечерам.` });
    const ac = sameEvening.filter(hasAcid);
    if (on('retinoid-acids') && ac.length) out.push({ rule: 'retinoid-acids', text: `Сегодня вечером уже были кислоты (${nameOf(ac)}). Ретиналь лучше в другой вечер.` });
    const bpo = sameDayAll.filter((i) => has(i, 'bpo'));
    if (on('retinoid-bpo') && bpo.length) out.push({ rule: 'retinoid-bpo', text: `Сегодня был бензоилпероксид (${nameOf(bpo)}) — с ретиналем лучше не совмещать.` });
    if (on('retinoid-acids-adjacent')) {
      const adj = [addDays(day, -1), addDays(day, 1)].flatMap((d) => dayItems(d, items, others).filter(hasAcid).map((i) => ({ i, d })));
      if (adj.length) out.push({ rule: 'retinoid-acids-adjacent', text: `${adjWord(adj[0].d, day)} были кислоты (${adj[0].i.name.toLowerCase()}). Между ними и ретиналем лучше день отдыха.` });
    }
  }

  if (has(item, 'azelaic') && on('retinoid-azelaic') && slot === 'evening') {
    const r = sameEvening.filter(isRetinoid);
    if (r.length) out.push({ rule: 'retinoid-azelaic', text: 'Сегодня вечер ретиналя. Пока вводишь ретиналь, азелаиновую лучше в другой вечер — меньше шансов на раздражение.' });
  }

  if (hasAcid(item)) {
    const r = sameEvening.filter(isRetinoid);
    if (on('retinoid-acids') && slot === 'evening' && r.length) out.push({ rule: 'retinoid-acids', text: 'Сегодня вечером был ретиналь. Кислоты лучше в другой вечер.' });
    if (on('retinoid-acids-adjacent')) {
      const adj = [addDays(day, -1), addDays(day, 1)].flatMap((d) => dayItems(d, items, others).filter(isRetinoid).map((i) => ({ i, d })));
      if (adj.length) out.push({ rule: 'retinoid-acids-adjacent', text: `${adjWord(adj[0].d, day)} был ретиналь. Кислоты лучше перенести, чтобы между ними был день отдыха.` });
    }
    if (on('acids-weekly')) {
      const from = addDays(day, -6);
      const acidDays = new Set(others.filter((e) => !e.skipped && e.day >= from && e.day <= day).filter((e) => { const it = items.find((i) => i.id === e.itemId); return it && hasAcid(it); }).map((e) => e.day));
      if (acidDays.size >= 2) out.push({ rule: 'acids-weekly', text: `Кислоты за последние 7 дней уже были ${acidDays.size} раза. Лучше не чаще 2 раз в неделю.` });
    }
  }
  return out;
}

const adjWord = (d, day) => (d < day ? `Накануне (${fmtShort(d)})` : `На следующий день (${fmtShort(d)})`);

// ---------- план дня ----------

/**
 * План на день: блоки morning / supplements / evening / optional.
 * Каждый пункт: { item, done, entry, hint?, deferred?, status? }.
 */
export function planForDay(state, day, today = day) {
  const { items, entries, rules } = state;
  const active = items.filter((i) => !i.archived);
  const dayEntries = entries.filter((e) => e.day === day && !e.skipped);
  const doneIds = new Set(dayEntries.map((e) => e.itemId));
  const retinoids = active.filter((i) => isRetinoid(i) && i.schedule?.type === 'interval');
  const retinoidStatuses = retinoids.map((i) => ({ item: i, st: intervalStatus(i, entries, day) }));
  const retinoidTonight = retinoidStatuses.some(({ st }) => ['today', 'overdue', 'done', 'notStarted'].includes(st.state));
  const blocks = { morning: [], supplements: [], evening: [], optional: [] };

  // SPF-акцент: вчера вечером был ретиноид или кислоты
  const yesterday = addDays(day, -1);
  const strongYesterday = dayItems(yesterday, active, entries).filter((i) => isRetinoid(i) || hasAcid(i));
  const spfAccent = rules['spf-after'] !== false && strongYesterday.length > 0;

  for (const item of active) {
    const entry = dayEntries.find((e) => e.itemId === item.id);
    const row = { item, done: doneIds.has(item.id), entry };
    if (isRetinoid(item) && item.schedule?.type === 'interval') {
      const st = retinoidStatuses.find((r) => r.item === item).st;
      row.status = st;
      if (st.state === 'resting') { blocks.optional.push({ ...row, deferred: `Отдыхает до ${whenWord(st.next, today)}` }); continue; }
      blocks.evening.unshift(row);
      continue;
    }
    if (item.actives.includes('spf') && spfAccent) row.accent = `После ${strongYesterday.some(isRetinoid) ? 'вчерашнего ретиналя' : 'вчерашних кислот'} кожа чувствительнее к солнцу`;
    const conflictsTonight = retinoidTonight && (
      (rules['retinoid-azelaic'] !== false && item.actives.includes('azelaic')) ||
      (rules['retinoid-acids'] !== false && hasAcid(item))
    );
    const block = item.block || 'optional';
    if (conflictsTonight && !row.done && (block === 'evening' || block === 'optional')) {
      blocks.optional.push({ ...row, deferred: 'Не сегодня: вечер ретиналя' });
      continue;
    }
    if (block === 'optional' && row.done) { blocks[entry?.slot === 'morning' ? 'morning' : 'evening'].push(row); continue; }
    blocks[block].push(row);
  }
  // отложенные — в конец «По желанию»
  blocks.optional.sort((a, b) => (a.deferred ? 1 : 0) - (b.deferred ? 1 : 0));
  return { blocks, retinoidStatuses, spfAccent };
}

/** Слот по умолчанию для отметки пункта. */
export function defaultSlot(item, now = new Date()) {
  if (item.block === 'morning' || item.block === 'supplements') return 'morning';
  if (item.block === 'evening' || isRetinoid(item)) return 'evening';
  const h = now.getHours();
  return h >= DAY_START_HOUR && h < 15 ? 'morning' : 'evening';
}

// ---------- статистика ----------

export function countInRange(itemId, entries, fromKey, toKey) {
  return new Set(entries.filter((e) => e.itemId === itemId && !e.skipped && e.day >= fromKey && e.day <= toKey).map((e) => e.day)).size;
}

// ---------- напоминания (.ics) ----------

export function morningTimeFor(reminders, key) {
  if (reminders.overrides?.[key]) return reminders.overrides[key];
  const wd = weekday(key);
  return wd === 0 || wd === 6 ? reminders.morning.weekend : reminders.morning.weekdays;
}

function icsEscape(s) { return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n'); }
const icsDate = (key, hhmm) => `${key.replace(/-/g, '')}T${hhmm.replace(':', '')}00`;
function fold(line) {
  const out = []; let s = line;
  while (s.length > 74) { out.push(s.slice(0, 74)); s = ' ' + s.slice(74); }
  out.push(s); return out.join('\r\n');
}

/**
 * Календарь с будильниками: утро будни/выходные (RRULE), вечер ежедневно,
 * разовые сдвиги утра — отдельными событиями с исключением регулярного (EXDATE).
 */
export function buildIcs(reminders, startKey, appUrl) {
  const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z');
  const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Ritm Kozhi//RU', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH', 'X-WR-CALNAME:Ритм кожи'];
  const overrides = Object.entries(reminders.overrides || {}).filter(([k]) => k >= startKey);
  const event = (uid, start, title, desc, rrule, exdates = []) => {
    lines.push('BEGIN:VEVENT', `UID:${uid}@ritm-kozhi`, `DTSTAMP:${stamp}`, `DTSTART:${start}`, `DURATION:PT10M`, fold(`SUMMARY:${icsEscape(title)}`), fold(`DESCRIPTION:${icsEscape(desc)}`));
    if (appUrl) lines.push(fold(`URL:${appUrl}`));
    if (rrule) lines.push(rrule);
    for (const x of exdates) lines.push(`EXDATE:${x}`);
    lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', fold(`DESCRIPTION:${icsEscape(title)}`), 'TRIGGER:PT0M', 'END:VALARM', 'END:VEVENT');
  };
  const firstWith = (pred) => { let k = startKey; while (!pred(weekday(k))) k = addDays(k, 1); return k; };
  const wdStart = firstWith((w) => w >= 1 && w <= 5);
  const weStart = firstWith((w) => w === 0 || w === 6);
  const morningDesc = `Магний и утренний уход. Открыть: ${appUrl || 'Ритм кожи'}`;
  const ex = (pred, hhmm) => overrides.filter(([k]) => pred(weekday(k))).map(([k]) => icsDate(k, hhmm));
  event('morning-weekdays', icsDate(wdStart, reminders.morning.weekdays), 'Магний и утренний уход', morningDesc, 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', ex((w) => w >= 1 && w <= 5, reminders.morning.weekdays));
  event('morning-weekend', icsDate(weStart, reminders.morning.weekend), 'Магний и утренний уход', morningDesc, 'RRULE:FREQ=WEEKLY;BYDAY=SA,SU', ex((w) => w === 0 || w === 6, reminders.morning.weekend));
  for (const [k, t] of overrides) event(`morning-once-${k}`, icsDate(k, t), 'Магний и утренний уход', morningDesc, null);
  event('evening', icsDate(startKey, reminders.evening), 'Вечерний уход', `Загляни, что сегодня вечером. Открыть: ${appUrl || 'Ритм кожи'}`, 'RRULE:FREQ=DAILY');
  lines.push('END:VCALENDAR');
  return lines.join('\r\n') + '\r\n';
}

// ---------- словарь INCI ----------

const INCI = [
  ['retinoid', ['retinal', 'retinaldehyde', 'retinol', 'retinyl', 'tretinoin', 'adapalene', 'hydroxypinacolone retinoate', 'granactive retinoid', 'ретиналь', 'ретинол', 'ретиноид']],
  ['aha', ['glycolic', 'lactic acid', 'mandelic', 'malic acid', 'tartaric', 'гликолев', 'молочн', 'миндальн']],
  ['bha', ['salicylic', 'betaine salicylate', 'willow bark', 'салицил']],
  ['pha', ['gluconolactone', 'lactobionic', 'глюконолактон']],
  ['azelaic', ['azelaic', 'potassium azeloyl', 'азелаин']],
  ['niacinamide', ['niacinamide', 'nicotinamide', 'ниацинамид']],
  ['vitc', ['ascorbic', 'ascorbyl', 'ethyl ascorbic', 'аскорбин']],
  ['peptides', ['peptide', 'palmitoyl', 'acetyl hexapeptide', 'argireline', 'matrixyl', 'copper tripeptide', 'пептид']],
  ['bpo', ['benzoyl peroxide', 'бензоилпероксид']],
  ['spf', ['spf', 'zinc oxide', 'titanium dioxide', 'avobenzone', 'octocrylene', 'tinosorb', 'uvinul', 'ethylhexyl methoxycinnamate', 'homosalate']],
];

/** Находит активы в тексте состава. Возвращает { actives:[id], matches:[{active, word, index}] }. */
export function detectActives(text) {
  const low = (text || '').toLowerCase();
  const found = new Map();
  const matches = [];
  for (const [active, words] of INCI) {
    for (const w of words) {
      let i = low.indexOf(w);
      while (i !== -1) {
        // citric acid в словарь не входит: в составах это почти всегда регулятор pH, а не AHA
        matches.push({ active, word: text.slice(i, i + w.length), index: i });
        found.set(active, true);
        i = low.indexOf(w, i + w.length);
      }
    }
  }
  return { actives: [...found.keys()], matches: matches.sort((a, b) => a.index - b.index) };
}

/** Какие правила затронет новое средство с такими активами — тексты для экрана добавления. */
export function conflictsPreview(actives, state) {
  const out = [];
  const hasRet = state.items.some((i) => !i.archived && isRetinoid(i));
  const acid = actives.some((a) => ACID_GROUP.includes(a));
  if (actives.includes('retinoid') && state.items.some((i) => !i.archived && isRetinoid(i))) out.push('У тебя уже есть ретиноид — второй вместе с ним лучше не использовать.');
  if (acid && hasRet) out.push('Не в один вечер с ретиналем и не в соседние вечера.');
  if (acid) out.push('Кислоты — не чаще 2 раз в неделю.');
  if (actives.includes('azelaic') && hasRet) out.push('Пока вводишь ретиналь — в другой вечер, чем он.');
  if (actives.includes('bpo') && hasRet) out.push('С ретиналем — не в одно нанесение.');
  if (actives.includes('retinoid')) out.push('Только вечером, с интервалом — как у ретиналя.');
  if (!out.length && actives.length) out.push('С твоим набором конфликтов нет.');
  return out;
}

// ---------- импорт/экспорт ----------

export function validateImport(obj) {
  if (!obj || typeof obj !== 'object') throw new Error('Это не файл копии «Ритма кожи».');
  if (!Array.isArray(obj.items) || !Array.isArray(obj.entries)) throw new Error('В файле нет списка средств или отметок.');
  if (obj.version > SCHEMA_VERSION) throw new Error('Копия сделана более новой версией приложения. Обнови страницу и попробуй снова.');
  const base = seedState();
  return { ...base, ...obj, rules: { ...base.rules, ...(obj.rules || {}) }, reminders: { ...base.reminders, ...(obj.reminders || {}) }, version: SCHEMA_VERSION };
}

export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
