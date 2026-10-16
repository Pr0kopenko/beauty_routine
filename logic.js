// Чистая логика «Ритма кожи»: дни, статус ретиноида, правила, план дня, .ics, словарь INCI.
// Без DOM — тестируется в Node (web/tests/logic.test.mjs).

export const SCHEMA_VERSION = 2;
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
export const fmtShort = (key) => { const d = keyToDate(key); return `${WEEKDAYS_SHORT[d.getDay()]},\u00a0${d.getDate()}\u00a0${MONTHS_GEN[d.getMonth()].slice(0, 3)}`; };
export const fmtLong = (key) => { const d = keyToDate(key); return `${WEEKDAYS_FULL[d.getDay()]}, ${d.getDate()} ${MONTHS_GEN[d.getMonth()]}`; };
export const fmtDayMonth = (key) => { const d = keyToDate(key); return `${d.getDate()}\u00a0${MONTHS_GEN[d.getMonth()]}`; };

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
export const daysWord = (n) => `${n}\u00a0${plural(n, 'день', 'дня', 'дней')}`;

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
  copper: { name: 'Медные пептиды', color: 'pep' },
  exfoliant: { name: 'Скраб или энзимы', color: 'acid' },
  bpo: { name: 'Бензоилпероксид', color: 'acid' },
  spf: { name: 'SPF', color: 'spf' },
  supplement: { name: 'Добавка', color: 'sup' },
};
export const ACID_GROUP = ['aha', 'bha', 'pha']; // азелаиновая сюда не входит

export const PRODUCT_TYPES = {
  cleanser: 'Очищение', toner: 'Тоник', serum: 'Сыворотка', cream: 'Крем', spf: 'SPF', mask: 'Маска', peel: 'Пилинг',
  eye: 'Для глаз', oil: 'Масло', spot: 'Точечное', supplement: 'Добавка', other: 'Другое',
};

// ---------- дневник кожи ----------
export const REACTIONS = {
  redness: 'Покраснение',
  dryness: 'Сухость, шелушение',
  burning: 'Жжение, пощипывание',
  breakouts: 'Высыпания',
};
export const LEVELS = ['нет', 'слабо', 'средне', 'сильно'];

/** Максимальный уровень реакции за день (0–3) или null, если записи нет. */
export function reactionLevel(state, day) {
  const d = state.diary?.[day];
  if (!d || !d.reactions) return null;
  const v = Object.values(d.reactions).filter((x) => typeof x === 'number');
  return v.length ? Math.max(...v) : null;
}
/** Максимальная реакция за последние n дней включая day. */
export function recentReaction(state, day, n = 3) {
  let m = 0;
  for (let i = 0; i < n; i++) { const l = reactionLevel(state, addDays(day, -i)); if (l != null && l > m) m = l; }
  return m;
}
/** Средства и активы за последние 48 часов (день и накануне). */
export function recentProducts(state, day) {
  const days = [day, addDays(day, -1)];
  const ids = [...new Set(state.entries.filter((e) => !e.skipped && days.includes(e.day)).map((e) => e.itemId))];
  return ids.map((id) => state.items.find((i) => i.id === id)).filter(Boolean);
}
/** Даты, когда средство появилось в истории впервые — для отметок «начала новое» на ленте фото. */
export function firstUseDays(state) {
  const first = new Map();
  for (const e of state.entries) { if (e.skipped || e.fromOnboarding) continue; if (!first.has(e.itemId) || e.day < first.get(e.itemId)) first.set(e.itemId, e.day); }
  return first;
}

/** Миграция старых данных (v1) в v2: тип средства, форма ретиноида, дневник. */
export function migrate(s) {
  s.diary = s.diary || {};
  for (const i of s.items) {
    if (!i.type) i.type = i.actives.includes('supplement') ? 'supplement' : i.actives.includes('spf') ? 'spf' : /крем/i.test(i.name) ? 'cream' : /сыворотк/i.test(i.name) ? 'serum' : /патч/i.test(i.name) ? 'eye' : 'other';
    if (i.actives.includes('retinoid') && !i.retinoidForm) i.retinoidForm = /ретинал|retinal/i.test(i.name) ? 'retinal' : 'retinol';
    if (i.brand == null) i.brand = '';
  }
  if ((s.version || 1) < 2 && s.rules) { s.rules['retinoid-acids-adjacent'] = false; }
  s.settings = { pregnancy: false, ...(s.settings || {}) };
  s.version = SCHEMA_VERSION;
  return s;
}

// Этапы введения ретиноида (эвристика приложения, см. ТЗ «Введение ретиноидов по формам»).
export const FREQUENCIES = {
  '1w': { label: '1 раз в неделю', short: '1×/нед', minDays: 7, maxPerWeek: 1 },
  '2w': { label: '2 раза в неделю', short: '2×/нед', minDays: 3, maxPerWeek: 2 },
  eod: { label: 'Через день', short: 'через день', minDays: 2, maxPerWeek: 4 },
  '5w': { label: '4–5 раз в неделю', short: '4–5×/нед', minDays: 1, maxPerWeek: 5 },
  daily: { label: 'Каждый вечер', short: 'каждый вечер', minDays: 1, maxPerWeek: 7 },
};
export const STAGE_ORDER = ['1w', '2w', 'eod', '5w', 'daily'];

export const RETINOID_FORMS = {
  retinyl_esters: { name: 'Ретиниловые эфиры', strength: 1, start: 'eod', weeks: 1, rx: false },
  hpr: { name: 'HPR (гидроксипинаколон ретиноат)', strength: 2, start: 'eod', weeks: 2, rx: false },
  retinol: { name: 'Ретинол', strength: 2, start: '2w', weeks: 2, rx: false },
  retinal: { name: 'Ретиналь', strength: 3, start: '2w', weeks: 2, rx: false },
  adapalene: { name: 'Адапален', strength: 3, start: 'eod', weeks: 2, rx: false },
  tretinoin: { name: 'Третиноин', strength: 5, start: '2w', weeks: 3, rx: true },
  tazarotene: { name: 'Тазаротен', strength: 5, start: '2w', weeks: 4, rx: true },
};

const has = (item, active) => item.actives.includes(active);
const hasAcid = (item) => item.actives.some((a) => ACID_GROUP.includes(a));
const isExfoliating = (item) => hasAcid(item) || item.actives.includes('exfoliant') || item.type === 'peel';
const isOxidizableRetinoid = (item) => isRetinoid(item) && item.retinoidForm !== 'adapalene';
export const isRetinoid = (item) => has(item, 'retinoid');

// ---------- стартовые данные ----------

export function seedState(sample = true) {
  const items = [
    { id: 'retinal', name: 'Ретиналь', note: 'корейский', actives: ['retinoid'], block: 'evening', schedule: { type: 'interval', freq: '2w' } },
    { id: 'aravia', name: 'Пептидная сыворотка Aravia', actives: ['peptides'], block: 'morning' },
    { id: 'aza-serum', name: 'Сыворотка с азелаиновой кислотой', actives: ['azelaic'], block: 'evening' },
    { id: 'aza-cream', name: 'Крем с азелаиновой кислотой', actives: ['azelaic'], block: 'optional' },
    { id: 'niac', name: 'Сыворотка с ниацинамидом', actives: ['niacinamide'], block: 'morning' },
    { id: 'spf', name: 'SPF Skin1004', actives: ['spf'], block: 'morning' },
    { id: 'eye-patch', name: 'Роллер-патчи для глаз', actives: [], block: 'optional' },
    { id: 'magnesium', name: 'Магний', actives: ['supplement'], block: 'supplements', dose: '' },
  ].map((it) => ({ archived: false, schedule: { type: 'daily' }, ...it }));
  for (const id of ['aza-cream', 'eye-patch']) items.find((i) => i.id === id).schedule = { type: 'asneeded' };
  return {
    version: SCHEMA_VERSION,
    onboarded: false,
    items: sample ? items : [],
    entries: [],
    rules: Object.fromEntries(RULES.map((r) => [r.id, r.defaultOn])),
    reminders: {
      morning: { weekdays: '07:45', weekend: '09:30' }, // пн–пт / сб–вс
      evening: '22:00',
      overrides: {}, // { 'YYYY-MM-DD': '07:15' } — разовый сдвиг утра
    },
    lastBackupAt: null,
    diary: {},
    settings: { pregnancy: false },
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
export function intervalStatus(item, entries, today, state = null) {
  const freq = FREQUENCIES[item.schedule?.freq] || FREQUENCIES['2w'];
  const minDays = freq.minDays;
  const last = lastDayOf(item.id, entries, today);
  const base = { minDays, last, freq: item.schedule?.freq || '2w' };
  if (state?.settings?.pregnancy) return { ...base, state: 'blocked', since: last ? daysBetween(last, today) : null, next: null };
  const since = last ? daysBetween(last, today) : null;
  if (since === 0) {
    const prev = lastDayOf(item.id, entries.filter((e) => !(e.itemId === item.id && e.day === today)), today);
    return { ...base, state: 'done', since, next: nextAllowed(item, entries, addDays(today, 1), today), prev };
  }
  const pause = state ? pauseInfo(state, today) : null;
  if (pause) return { ...base, state: 'paused', since, next: pause.until, pause };
  if (!last) return { ...base, state: 'notStarted', since: null, next: today };
  const next = nextAllowed(item, entries, today, today);
  if (next > today) return { ...base, state: 'resting', since, next };
  if (since <= minDays + 2) return { ...base, state: 'today', since, next: today };
  return { ...base, state: 'overdue', since, next: today };
}

/** Ближайший день ≥ from, когда можно: интервал от последнего раза и лимит в неделю. */
export function nextAllowed(item, entries, from, today) {
  const freq = FREQUENCIES[item.schedule?.freq] || FREQUENCIES['2w'];
  const days = [...new Set(entries.filter((e) => e.itemId === item.id && !e.skipped && e.day <= addDays(from, 7)).map((e) => e.day))].sort();
  for (let d = from, i = 0; i < 30; i++, d = addDays(d, 1)) {
    const before = days.filter((x) => x < d);
    const lastB = before[before.length - 1];
    if (lastB && daysBetween(lastB, d) < freq.minDays) continue;
    const inWeek = days.filter((x) => x >= addDays(d, -6) && x < d).length;
    if (inWeek >= freq.maxPerWeek) continue;
    return d;
  }
  return addDays(from, freq.minDays);
}

/** Пауза ретиноида из-за реакции кожи: средне → 2–3 дня, сильно → пока реакция не уйдёт. */
export function pauseInfo(state, today) {
  for (let i = 0; i <= 3; i++) {
    const d = addDays(today, -i);
    const l = irritationLevel(state, d);
    if (l >= 3) {
      // сильная — пауза, пока не будет записи с раздражением 0 после неё
      for (let j = i - 1; j >= 0; j--) { const lj = irritationLevel(state, addDays(today, -j)); if (lj === 0) return null; }
      return { level: 3, since: d, until: addDays(today, 1) };
    }
    if (l === 2 && i < 3) return { level: 2, since: d, until: addDays(d, 3) };
  }
  return null;
}
/** Раздражение = покраснение, сухость, жжение (высыпания — отдельно, это может быть пурджинг). */
export function irritationLevel(state, day) {
  const r = state.diary?.[day]?.reactions;
  if (!r) return null;
  return Math.max(r.redness || 0, r.dryness || 0, r.burning || 0);
}

/** Совет по графику ретиноида: шаг вверх, шаг вниз, врач. null — всё идёт как надо. */
export function retinoidAdvice(item, state, today) {
  if (!isRetinoid(item) || item.schedule?.type !== 'interval' || state.settings?.pregnancy) return null;
  const form = RETINOID_FORMS[item.retinoidForm] || RETINOID_FORMS.retinol;
  const cur = item.schedule.freq || '2w';
  const idx = STAGE_ORDER.indexOf(cur);
  const pause = pauseInfo(state, today);
  if (pause?.level === 3) return { kind: 'doctor', text: 'Сильная реакция. Пауза, пока кожа не успокоится, потом заново с 2 раз в неделю. Если не проходит за несколько дней — покажись дерматологу.', to: '2w' };
  if (pause?.level === 2 && idx > 1) return { kind: 'down', text: `Кожа реагирует. Пауза до ${fmtShort(pause.until)}, а потом лучше шаг назад — ${FREQUENCIES[STAGE_ORDER[idx - 1]].label.toLowerCase()}.`, to: STAGE_ORDER[idx - 1] };
  if (pause) return null;
  if (form.rx || idx >= STAGE_ORDER.length - 1 || idx < 0) return null;
  const since = item.schedule.since || firstDayAtFreq(item, state);
  if (!since) return null;
  if (item.schedule.snoozeUntil && item.schedule.snoozeUntil > today) return null;
  const days = daysBetween(since, today);
  const apps = new Set(state.entries.filter((e) => e.itemId === item.id && !e.skipped && e.day >= since && e.day <= today).map((e) => e.day)).size;
  let worst = 0; for (let i = 0; i < 7; i++) { const l = irritationLevel(state, addDays(today, -i)); if (l != null && l > worst) worst = l; }
  if (days >= form.weeks * 7 && apps >= 3 && worst < 2) {
    const to = STAGE_ORDER[idx + 1];
    return { kind: 'up', text: `${daysWord(days)} на частоте «${FREQUENCIES[cur].label.toLowerCase()}» без заметных реакций. Можно перейти на «${FREQUENCIES[to].label.toLowerCase()}».`, to };
  }
  return null;
}
function firstDayAtFreq(item, state) {
  const d = state.entries.filter((e) => e.itemId === item.id && !e.skipped).map((e) => e.day).sort();
  return d[0] || null;
}

export function statusText(item, st, today) {
  const n = item.name;
  switch (st.state) {
    case 'notStarted': return { title: `${n}: можно начать сегодня`, sub: 'Отметь, когда нанесёшь, — дальше посчитаю сама.' };
    case 'done': return { title: `${n} нанесён ✓`, sub: `Следующий — ${whenWord(st.next, today)}, ${fmtDayMonth(st.next)}.` };
    case 'resting': return { title: `${n} отдыхает`, sub: `Был ${whenWord(st.last, today)}. Следующий — ${whenWord(st.next, today)} вечером.` };
    case 'today': return { title: `Сегодня вечер — ${n}`, sub: `Прошло ${daysWord(st.since)} — можно.` };
    case 'overdue': return { title: `${n} ждёт уже ${daysWord(st.since)}`, sub: 'Можно сегодня вечером.' };
    case 'paused': return { title: `${n}: пауза`, sub: `Кожа реагирует. Отдыхаем до ${fmtShort(st.next)}.` };
    case 'blocked': return { title: `${n} на паузе`, sub: 'Включён режим беременности и ГВ — ретиноиды не планирую.' };
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
    case 'overdue': return { title: `Прошло ${daysWord(st.since)} — самое время`, sub: `Последний раз ${fmtShort(st.last)} · ${freq}.` };
    case 'paused': return { title: 'Пауза из-за реакции кожи', sub: `${st.pause?.level >= 3 ? 'Пока кожа не успокоится' : 'До ' + fmtShort(st.next)} — без ретиноида и кислот, только мягкий уход.` };
    case 'blocked': return { title: 'Ретиноиды на паузе', sub: 'Режим беременности и ГВ. Выключить — в «Ещё».' };
    default: return { title: item.name, sub: '' };
  }
}

// ---------- правила ----------

// Правила совместимости. conf — уровень доказательности (см. ТЗ «Совместимость активов»).
const AAD_EXF = 'https://www.aad.org/public/everyday-care/skin-care-secrets/routine/safely-exfoliate-at-home';
const AAD_RET = 'https://www.aad.org/public/everyday-care/skin-care-secrets/anti-aging/retinoid-retinol';
export const RULES = [
  { id: 'retinoid-interval', text: 'Ретиноид — по графику введения', sub: 'интервал и число раз в неделю по этапу', conf: 'эвристика', defaultOn: true },
  { id: 'retinoid-evening', text: 'Ретиноид — только вечером', sub: 'разрушается на свету', conf: 'высокий', src: AAD_RET, defaultOn: true },
  { id: 'retinoid-acids', text: 'Ретиноид и AHA/BHA/PHA — разные вечера', sub: 'вместе сильнее сушит; в соседние дни можно', conf: 'средний', src: AAD_EXF, defaultOn: true },
  { id: 'retinoid-azelaic', text: 'Ретиноид и азелаиновая — разные вечера', sub: 'мягкая осторожность на время введения; по исследованиям сочетать можно', conf: 'низкий', defaultOn: true },
  { id: 'retinoid-bpo', text: 'Ретинол/ретиналь/третиноин и бензоилпероксид — в разное время суток', sub: 'БПО окисляет ретиноиды; адапален устойчив', conf: 'высокий', src: 'https://pubmed.ncbi.nlm.nih.gov/9990414/', defaultOn: true },
  { id: 'vitc-retinoid', text: 'Витамин C — утром, ретиноид — вечером', sub: '', conf: 'низкий', src: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC5605218/', defaultOn: true },
  { id: 'vitc-acids', text: 'Витамин C и кислоты — в разное время суток', sub: 'оба кислотные, вместе больше раздражения', conf: 'низкий', defaultOn: true },
  { id: 'vitc-bpo', text: 'Витамин C и бензоилпероксид — в разное время суток', sub: 'БПО окисляет витамин C', conf: 'средний', defaultOn: true },
  { id: 'bpo-acids', text: 'Бензоилпероксид и кислоты — разные дни', sub: '', conf: 'средний', src: 'https://dermnetnz.org/topics/salicylic-acid', defaultOn: true },
  { id: 'one-exfoliant', text: 'Один эксфолиант за день', sub: 'кислоты, скраб, энзимы, пилинг-маска — в разные дни', conf: 'средний', src: AAD_EXF, defaultOn: true },
  { id: 'copper-acids', text: 'Медные пептиды отдельно от кислот и витамина C', sub: 'при низком pH комплекс меди может распадаться', conf: 'низкий', defaultOn: true },
  { id: 'acids-weekly', text: 'Кислоты AHA/BHA — до 2–3 раз в неделю', sub: 'подсказка с третьего раза за 7 дней', conf: 'эвристика', defaultOn: true },
  { id: 'retinoid-acids-adjacent', text: 'Ретиноид и кислоты — не в соседние вечера', sub: 'строже, чем нужно по данным; для чувствительной кожи', conf: 'низкий', defaultOn: false },
  { id: 'spf-after', text: 'SPF утром после ретиноида или кислот', sub: 'выделю SPF на утро', conf: 'высокий', src: 'https://www.fda.gov/cosmetics/cosmetic-ingredients/alpha-hydroxy-acids', defaultOn: true },
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
  const nameOf = (list) => list.map((i) => i.name).join(', ');

  if (isRetinoid(item)) {
    if (state.settings?.pregnancy) out.push({ rule: 'pregnancy', text: 'Включён режим беременности и ГВ — ретиноиды в это время не используют.' });
    const pz = pauseInfo(state, day);
    if (pz) out.push({ rule: 'pause', text: 'Кожа сейчас реагирует. Ретиноид лучше отложить, пока она не успокоится.' });
    if (on('retinoid-interval')) {
      const minDays = (FREQUENCIES[item.schedule?.freq] || FREQUENCIES['2w']).minDays;
      const prev = lastDayOf(item.id, others, day);
      const nextAfter = entries.filter((e) => e.itemId === item.id && !e.skipped && e.day > day).map((e) => e.day).sort()[0];
      if (prev && daysBetween(prev, day) < minDays) {
        out.push({ rule: 'retinoid-interval', text: `До этого «${item.name}» был ${fmtShort(prev)} — всего ${daysWord(daysBetween(prev, day))} назад, а по частоте нужно ${daysWord(minDays)}. Можно с ${fmtShort(addDays(prev, minDays))}.` });
      } else if (nextAfter && daysBetween(day, nextAfter) < minDays) {
        out.push({ rule: 'retinoid-interval', text: `Через ${daysWord(daysBetween(day, nextAfter))} уже отмечен «${item.name}» — интервал будет короче ${daysWord(minDays)}.` });
      }
    }
    if (on('retinoid-evening') && slot === 'morning') out.push({ rule: 'retinoid-evening', text: `${item.name} лучше наносить вечером: ретиноиды разрушаются на свету.` });
    const az = sameEvening.filter((i) => has(i, 'azelaic'));
    if (on('retinoid-azelaic') && az.length) out.push({ rule: 'retinoid-azelaic', text: `Сегодня вечером уже была ${nameOf(az)}. Пока вводишь ретиноид, их лучше разнести по разным вечерам.` });
    const ac = sameEvening.filter(hasAcid);
    if (on('retinoid-acids') && ac.length) out.push({ rule: 'retinoid-acids', text: `Сегодня вечером уже были кислоты (${nameOf(ac)}). Ретиноид лучше в другой вечер.` });
    if (on('retinoid-acids-adjacent')) {
      const adj = [addDays(day, -1), addDays(day, 1)].flatMap((d) => dayItems(d, items, others).filter(hasAcid).map((i) => ({ i, d })));
      if (adj.length) out.push({ rule: 'retinoid-acids-adjacent', text: `${adjWord(adj[0].d, day)} были кислоты (${adj[0].i.name}). Для чувствительной кожи лучше день отдыха между ними.` });
    }
  }

  if (has(item, 'azelaic') && on('retinoid-azelaic') && slot === 'evening') {
    const r = sameEvening.filter(isRetinoid);
    if (r.length) out.push({ rule: 'retinoid-azelaic', text: 'Сегодня вечер ретиноида — азелаиновую лучше в другой вечер, пока идёт введение. Утром можно.' });
  }

  if (hasAcid(item)) {
    const r = sameEvening.filter(isRetinoid);
    if (on('retinoid-acids') && slot === 'evening' && r.length) out.push({ rule: 'retinoid-acids', text: 'Сегодня вечером был ретиноид. Кислоты лучше в другой вечер.' });
    if (on('retinoid-acids-adjacent')) {
      const adj = [addDays(day, -1), addDays(day, 1)].flatMap((d) => dayItems(d, items, others).filter(isRetinoid).map((i) => ({ i, d })));
      if (adj.length) out.push({ rule: 'retinoid-acids-adjacent', text: `${adjWord(adj[0].d, day)} был ретиноид. Кислоты лучше перенести, чтобы между ними был день отдыха.` });
    }
    if (on('acids-weekly')) {
      const from = addDays(day, -6);
      const acidDays = new Set(others.filter((e) => !e.skipped && e.day >= from && e.day <= day).filter((e) => { const it = items.find((i) => i.id === e.itemId); return it && hasAcid(it); }).map((e) => e.day));
      if (acidDays.size >= 2) out.push({ rule: 'acids-weekly', text: `Кислоты за последние 7 дней уже были ${acidDays.size} раза. Лучше не чаще 2–3 раз в неделю.` });
    }
  }

  // пары «в одно время суток» и «в один день»
  const sameSlot = dayItems(day, items, others, slot);
  const pair = (id, mine, theirs, list, text) => {
    if (!on(id) || !mine(item)) return;
    const hit = list.filter(theirs);
    if (hit.length && !out.some((o) => o.rule === id)) out.push({ rule: id, text: text(nameOf(hit)) });
  };
  const has_ = (a) => (i) => i.actives.includes(a);
  pair('retinoid-bpo', isOxidizableRetinoid, has_('bpo'), sameSlot, (n) => `В это же время уже был бензоилпероксид (${n}) — он окисляет ретиноид. Лучше БПО утром, ретиноид вечером.`);
  pair('retinoid-bpo', has_('bpo'), isOxidizableRetinoid, sameSlot, (n) => `В это же время уже был ретиноид (${n}) — бензоилпероксид его окисляет. Лучше утром.`);
  pair('vitc-retinoid', has_('vitc'), isRetinoid, sameSlot, (n) => `В это же время был ретиноид (${n}). Витамин C лучше утром.`);
  pair('vitc-retinoid', isRetinoid, has_('vitc'), sameSlot, (n) => `В это же время был витамин C (${n}). Удобнее: C утром, ретиноид вечером.`);
  pair('vitc-acids', has_('vitc'), hasAcid, sameSlot, (n) => `В это же время были кислоты (${n}). Витамин C лучше в другое время суток.`);
  pair('vitc-acids', hasAcid, has_('vitc'), sameSlot, (n) => `В это же время был витамин C (${n}). Кислоты лучше в другое время суток.`);
  pair('vitc-bpo', has_('vitc'), has_('bpo'), sameSlot, (n) => `В это же время был бензоилпероксид (${n}) — он окисляет витамин C.`);
  pair('vitc-bpo', has_('bpo'), has_('vitc'), sameSlot, (n) => `В это же время был витамин C (${n}) — бензоилпероксид его окисляет.`);
  pair('bpo-acids', has_('bpo'), hasAcid, sameDayAll, (n) => `Сегодня уже были кислоты (${n}). С бензоилпероксидом лучше в разные дни.`);
  pair('bpo-acids', hasAcid, has_('bpo'), sameDayAll, (n) => `Сегодня уже был бензоилпероксид (${n}). Кислоты лучше в другой день.`);
  pair('one-exfoliant', isExfoliating, isExfoliating, sameDayAll, (n) => `Сегодня уже была эксфолиация (${n}). Одного раза в день достаточно — иначе легко пересушить кожу.`);
  pair('copper-acids', has_('copper'), (i) => hasAcid(i) || i.actives.includes('vitc'), sameSlot, (n) => `В это же время были кислоты или витамин C (${n}). Медные пептиды лучше отдельно.`);
  pair('copper-acids', (i) => hasAcid(i) || i.actives.includes('vitc'), has_('copper'), sameSlot, (n) => `В это же время были медные пептиды (${n}). Лучше в другое время суток.`);
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
  const retinoidStatuses = retinoids.map((i) => ({ item: i, st: intervalStatus(i, entries, day, state) }));
  const retinoidTonight = retinoidStatuses.some(({ st }) => ['today', 'overdue', 'done', 'notStarted'].includes(st.state));
  const blocks = { morning: [], supplements: [], evening: [], optional: [] };

  // SPF-акцент: вчера вечером был ретиноид или кислоты
  const yesterday = addDays(day, -1);
  const strongYesterday = dayItems(yesterday, active, entries).filter((i) => isRetinoid(i) || hasAcid(i));
  const spfAccent = rules['spf-after'] !== false && strongYesterday.length > 0;
  const paused = retinoidStatuses.some(({ st }) => st.state === 'paused');

  for (const item of active) {
    const entry = dayEntries.find((e) => e.itemId === item.id);
    const row = { item, done: doneIds.has(item.id), entry };
    if (isRetinoid(item) && item.schedule?.type === 'interval') {
      const st = retinoidStatuses.find((r) => r.item === item).st;
      row.status = st;
      if (st.state === 'resting' && !row.done) { blocks.optional.push({ ...row, deferred: `Отдыхает до ${whenWord(st.next, today)}` }); continue; }
      if (st.state === 'paused' && !row.done) { blocks.optional.push({ ...row, deferred: 'Пауза: кожа реагирует' }); continue; }
      if (st.state === 'blocked' && !row.done) { blocks.optional.push({ ...row, deferred: 'Режим беременности и ГВ' }); continue; }
      blocks.evening.unshift(row);
      continue;
    }
    if (item.actives.includes('spf') && spfAccent) row.accent = `После ${strongYesterday.some(isRetinoid) ? 'вчерашнего ретиноида' : 'вчерашних кислот'} кожа чувствительнее к солнцу`;
    const conflictsTonight = retinoidTonight && (
      (rules['retinoid-azelaic'] !== false && item.actives.includes('azelaic')) ||
      (rules['retinoid-acids'] !== false && hasAcid(item))
    );
    const block = item.block || 'optional';
    if (paused && hasAcid(item) && !row.done) { blocks.optional.push({ ...row, deferred: 'Пауза: кожа реагирует — кислоты потом' }); continue; }
    if (conflictsTonight && !row.done && (block === 'evening' || block === 'optional')) {
      blocks.optional.push({ ...row, deferred: 'Не сегодня: вечер ретиноида' });
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
  ['copper', ['copper tripeptide', 'ghk-cu', 'медные пептиды']],
  ['peptides', ['peptide', 'palmitoyl', 'acetyl hexapeptide', 'argireline', 'matrixyl', 'пептид']],
  ['exfoliant', ['papain', 'bromelain', 'subtilisin', 'папаин', 'бромелайн']],
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
  if (acid && hasRet) out.push('Не в один вечер с ретиноидом.');
  if (acid) out.push('Кислоты — не чаще 2 раз в неделю.');
  if (actives.includes('azelaic') && hasRet) out.push('Пока вводишь ретиноид — лучше в другой вечер (мягкая осторожность).');
  if (actives.includes('bpo') && hasRet) out.push('С ретиноидом — в разное время суток (кроме адапалена).');
  if (actives.includes('retinoid')) out.push('Только вечером, по графику введения.');
  if (!out.length && actives.length) out.push('С твоим набором конфликтов нет.');
  return out;
}

// ---------- импорт/экспорт ----------

export function validateImport(obj) {
  if (!obj || typeof obj !== 'object') throw new Error('Это не файл копии «Ритма кожи».');
  if (!Array.isArray(obj.items) || !Array.isArray(obj.entries)) throw new Error('В файле нет списка средств или отметок.');
  if (obj.version > SCHEMA_VERSION) throw new Error('Копия сделана более новой версией приложения. Обнови страницу и попробуй снова.');
  const base = seedState();
  return migrate({ ...base, ...obj, rules: { ...base.rules, ...(obj.rules || {}) }, reminders: { ...base.reminders, ...(obj.reminders || {}) }, settings: { ...base.settings, ...(obj.settings || {}) }, diary: obj.diary || {}, version: obj.version || 1 });
}

export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
