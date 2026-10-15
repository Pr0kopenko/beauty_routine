import * as L from './logic.js';

const VERSION = '0.2.0';
const KEY = 'ritm-kozhi-v1';
const APP_URL = new URL('./', location.href).href;

// ---------- иконки ----------
const I = {
  check: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 8.5l3 3 6-7"/></svg>',
  plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
  chev: '<svg class="chev" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 5l5 5-5 5"/></svg>',
  chevDown: '<svg class="chev" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 8l5 5 5-5"/></svg>',
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>',
  close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  drop: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 2.5c2.9 3.6 5 6.4 5 9a5 5 0 0 1-10 0c0-2.6 2.1-5.4 5-9z"/></svg>',
  warn: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 2l8.5 15h-17L10 2zm-.9 5.5v4.8h1.8V7.5H9.1zm0 6.2v1.8h1.8v-1.8H9.1z"/></svg>',
  ok: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 1.8a8.2 8.2 0 1 1 0 16.4 8.2 8.2 0 0 1 0-16.4zm3.6 5.3L8.9 11.8 6.4 9.3 5.2 10.5l3.7 3.7 5.9-5.9-1.2-1.2z"/></svg>',
  empty: '<svg viewBox="0 0 40 40" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="6" y="9" width="28" height="25" rx="5"/><path d="M6 16h28M14 5v7M26 5v7"/></svg>',
  tToday: '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="13" cy="13" r="8.5"/><path class="fillable" d="M13 4.5a8.5 8.5 0 0 1 0 17z" stroke="none"/><path d="M13 4.5v17"/></svg>',
  tHistory: '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><rect class="fillable" x="4.5" y="5.5" width="17" height="16" rx="3.5" fill-opacity=".14"/><path d="M4.5 10h17"/><circle cx="9.5" cy="14.5" r="1.4" fill="currentColor" stroke="none"/><circle cx="16.5" cy="14.5" r="1.4" fill="currentColor" stroke="none"/><circle cx="13" cy="18" r="1.4" fill="currentColor" stroke="none"/></svg>',
  tProducts: '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M10.5 3.5h5v3.5h-5z"/><path d="M9 7h8l.8 3H8.2z"/><rect x="7.5" y="10" width="11" height="12.5" rx="3"/><path class="fillable" d="M10 16h6v4h-6z" stroke="none"/></svg>',
  tMore: '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M5 9h16M5 17h16"/><circle class="fillable" cx="10" cy="9" r="2.4"/><circle class="fillable" cx="16" cy="17" r="2.4"/></svg>',
};

// ---------- состояние ----------
let S = load();
const ui = { tab: 'today', view: null, param: null, optionalOpen: false, histMonth: null, histDay: null, obStep: 0, ob: {}, sheet: null, toast: null, bannerHidden: false };

function load() {
  try { const raw = localStorage.getItem(KEY); if (raw) return L.validateImport(JSON.parse(raw)); } catch (e) { console.warn(e); }
  return L.seedState();
}
function save() {
  try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { toast('Не получилось сохранить: память браузера недоступна.'); }
}
async function askPersist() { try { if (navigator.storage?.persist && !(await navigator.storage.persisted())) await navigator.storage.persist(); } catch {} }

const today = () => L.dayKey(new Date());
const itemById = (id) => S.items.find((i) => i.id === id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nowHHMM = () => { const d = new Date(); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
const isStandalone = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
const isIOS = () => /iP(hone|ad|od)/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

function colorClass(item) {
  const a = item.actives[0];
  if (!a) return 'c-none';
  return 'c-' + (L.ACTIVES[a]?.color || 'none');
}
function dotHtml(item) {
  const a = item.actives[0];
  const ring = a && L.ACID_GROUP.includes(a) ? ' ring-dot' : '';
  return `<i class="dot ${colorClass(item)}${ring}" aria-hidden="true"></i>`;
}

// ---------- действия с отметками ----------
function addEntry(itemId, day, slot, overrode = false) {
  const h = new Date().getHours(); const period = h >= L.DAY_START_HOUR && h < 15 ? 'morning' : 'evening';
  const e = { id: L.uid(), itemId, day, slot, at: new Date().toISOString(), time: day === today() && slot === period ? nowHHMM() : null };
  if (overrode) e.overrode = true;
  S.entries.push(e); save(); return e;
}
function removeEntry(id) { const e = S.entries.find((x) => x.id === id); S.entries = S.entries.filter((x) => x.id !== id); save(); return e; }

function tryMark(itemId, day, slot, { after } = {}) {
  const hints = L.checkMark({ itemId, day, slot }, S);
  if (!hints.length) { const e = addEntry(itemId, day, slot); markedToast(e); after?.(); render(); return; }
  openSheet({ type: 'hint', itemId, day, slot, hints, after });
}
function markedToast(e) {
  const it = itemById(e.itemId);
  toast(`${it.name} — отмечено`, { label: 'Отменить', fn: () => { removeEntry(e.id); render(); } });
}
function toggleRow(itemId) {
  const d = today();
  const existing = S.entries.filter((e) => e.itemId === itemId && e.day === d && !e.skipped);
  if (existing.length) {
    existing.forEach((e) => removeEntry(e.id));
    toast('Отметка снята', { label: 'Вернуть', fn: () => { existing.forEach((e) => S.entries.push(e)); save(); render(); } });
    render(); return;
  }
  const it = itemById(itemId);
  tryMark(itemId, d, L.defaultSlot(it));
}
function markAll(blockName) {
  const d = today();
  const plan = L.planForDay(S, d);
  const rows = plan.blocks[blockName].filter((r) => !r.done && !r.deferred);
  const added = [];
  for (const r of rows) {
    if (L.checkMark({ itemId: r.item.id, day: d, slot: blockName === 'evening' ? 'evening' : 'morning' }, S).length) continue;
    added.push(addEntry(r.item.id, d, blockName === 'evening' ? 'evening' : 'morning'));
  }
  if (added.length) toast(`Отмечено: ${added.length}`, { label: 'Отменить', fn: () => { added.forEach((e) => removeEntry(e.id)); render(); } });
  render();
}

// ---------- toast ----------
let toastTimer;
function toast(text, action) {
  ui.toast = { text, action };
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { ui.toast = null; renderToast(); }, action ? 5000 : 3000);
  renderToast();
}
function renderToast() {
  let el = document.querySelector('.toast');
  if (!ui.toast) { el?.remove(); return; }
  if (!el) { el = document.createElement('div'); el.className = 'toast'; el.setAttribute('role', 'status'); document.body.appendChild(el); }
  el.innerHTML = `<span>${esc(ui.toast.text)}</span>${ui.toast.action ? `<button data-act="toast-action">${esc(ui.toast.action.label)}</button>` : ''}`;
}

// ---------- шторки ----------
function openSheet(s) { ui.sheet = s; renderSheet(); }
function closeSheet() { ui.sheet = null; renderSheet(); }
function renderSheet() {
  let el = document.querySelector('.overlay');
  if (!ui.sheet) { el?.remove(); return; }
  if (!el) { el = document.createElement('div'); el.className = 'overlay'; document.body.appendChild(el); el.addEventListener('click', (ev) => { if (ev.target === el) closeSheet(); }); }
  el.innerHTML = `<div class="sheet" role="dialog" aria-modal="true">${sheetHtml(ui.sheet)}</div>`;
}
function sheetHead(title) {
  return `<div class="grab"></div><div class="head"><h2>${title}</h2><button class="close" data-act="close-sheet" aria-label="Закрыть">${I.close}</button></div>`;
}
function hintsHtml(hints, cls = 'warn') {
  return `<div class="hint ${cls}">${cls === 'warn' ? I.warn : I.drop}<div>${hints.map((h) => `<p>${esc(h.text)}</p>`).join('')}</div></div>`;
}
function sheetHtml(s) {
  if (s.type === 'hint') {
    const it = itemById(s.itemId);
    return `${sheetHead('Подсказка')}
      <p class="muted">${esc(it.name)} · ${esc(L.whenWord(s.day, today()))}, ${s.slot === 'evening' ? 'вечер' : 'утро'}</p>
      ${hintsHtml(s.hints)}
      <p class="small muted">Правило можно выключить в «Ещё → Правила». Решаешь ты.</p>
      <div class="stack"><button class="btn" data-act="close-sheet">Не отмечать</button><button class="btn sec" data-act="force-mark">Всё равно отметить</button></div>`;
  }
  if (s.type === 'deferred') {
    const it = itemById(s.itemId);
    const morningOk = !L.isRetinoid(it) && !L.checkMark({ itemId: it.id, day: today(), slot: 'morning' }, S).length;
    return `${sheetHead(esc(it.name))}${hintsHtml([{ text: s.reason }], 'soft')}
      <div class="stack"><button class="btn" data-act="close-sheet">Понятно</button>
      ${morningOk ? `<button class="btn sec" data-act="mark-slot" data-id="${it.id}" data-slot="morning">Нанесла утром</button>` : ''}
      <button class="btn sec" data-act="force-mark-today" data-id="${it.id}">Всё равно отметить${morningOk ? ' вечером' : ''}</button></div>`;
  }
  if (s.type === 'mark') {
    const items = S.items.filter((i) => !i.archived);
    const t = today();
    const dayOpts = [[t, 'Сегодня'], [L.addDays(t, -1), 'Вчера'], [L.addDays(t, -2), 'Позавчера']];
    const custom = !dayOpts.some(([k]) => k === s.day);
    const hints = s.itemId ? L.checkMark({ itemId: s.itemId, day: s.day, slot: s.slot }, S) : [];
    const already = s.itemId && S.entries.some((e) => e.itemId === s.itemId && e.day === s.day && !e.skipped);
    return `${sheetHead('Отметить')}
      <div class="field"><label for="m-item">Что</label><select id="m-item" data-change="m-item">${items.map((i) => `<option value="${i.id}" ${i.id === s.itemId ? 'selected' : ''}>${esc(i.name)}</option>`).join('')}</select></div>
      <div><p class="sec">Когда</p>
        <div class="seg">${dayOpts.map(([k, l]) => `<button data-act="m-day" data-day="${k}" aria-pressed="${k === s.day}">${l}</button>`).join('')}
        <button data-act="m-day-custom" aria-pressed="${custom}">${custom ? esc(L.fmtShort(s.day)) : 'Дата…'}</button></div>
        ${s.showDate || custom ? `<div class="field" style="margin-top:10px"><label for="m-date">Дата</label><input id="m-date" type="date" max="${t}" value="${s.day}" data-change="m-date"></div>` : ''}
      </div>
      <div class="seg"><button data-act="m-slot" data-slot="morning" aria-pressed="${s.slot === 'morning'}">Утро</button><button data-act="m-slot" data-slot="evening" aria-pressed="${s.slot === 'evening'}">Вечер</button></div>
      ${already ? hintsHtml([{ text: 'В этот день уже есть такая отметка.' }], 'soft') : ''}
      ${hints.length ? hintsHtml(hints) : ''}
      ${already ? `<button class="btn" disabled>Уже отмечено</button>` : hints.length
        ? `<div class="stack"><button class="btn" data-act="close-sheet">Не отмечать</button><button class="btn sec" data-act="m-save" data-force="1">Всё равно отметить</button></div>`
        : `<button class="btn" data-act="m-save">Отметить</button>`}`;
  }
  if (s.type === 'confirm') {
    return `${sheetHead(esc(s.title))}<p class="muted">${esc(s.text)}</p>
      <div class="stack"><button class="btn danger" data-act="confirm-yes">${esc(s.yes)}</button><button class="btn sec" data-act="close-sheet">Отмена</button></div>`;
  }
  if (s.type === 'install') {
    return `${sheetHead('Поставь на экран «Домой»')}
      <p>Так «Ритм кожи» откроется как приложение и будет работать без интернета.</p>
      <ol style="margin:0;padding-left:20px;display:flex;flex-direction:column;gap:6px">
        <li>Нажми кнопку «Поделиться» внизу Safari (квадрат со стрелкой).</li>
        <li>Выбери «На экран „Домой“».</li>
        <li>Открывай приложение только с иконки.</li></ol>
      ${hintsHtml([{ text: 'У вкладки Safari и у иконки разная память: отметки, сделанные во вкладке, не видны в иконке. Если уже что-то отметила здесь — сохрани копию (Ещё → Экспорт) и восстанови её в иконке.' }], 'soft')}
      <button class="btn" data-act="close-sheet">Понятно</button>`;
  }
  return '';
}

// ---------- экраны ----------
function render() {
  const app = document.getElementById('app');
  if (!S.onboarded) { app.innerHTML = onboardingHtml(); document.querySelector('.tabbar')?.remove(); return; }
  let html = '';
  if (ui.view === 'product') html = productHtml(ui.param);
  else if (ui.view === 'edit') html = editHtml(ui.param);
  else if (ui.view === 'reminders') html = remindersHtml();
  else if (ui.tab === 'today') html = todayHtml();
  else if (ui.tab === 'history') html = historyHtml();
  else if (ui.tab === 'products') html = productsHtml();
  else if (ui.tab === 'more') html = moreHtml();
  app.innerHTML = html;
  renderChrome();
}
function renderChrome() {
  let tb = document.querySelector('.tabbar');
  if (!tb) { tb = document.createElement('div'); tb.className = 'tabbar'; document.body.appendChild(tb); }
  const tabs = [['today', 'Сегодня', I.tToday], ['history', 'История', I.tHistory], ['products', 'Средства', I.tProducts], ['more', 'Ещё', I.tMore]];
  tb.innerHTML = `<nav aria-label="Разделы">${tabs.map(([id, l, ic]) => `<button data-act="tab" data-tab="${id}" ${ui.tab === id && !ui.view ? 'aria-current="page"' : ''}>${ic}<span>${l}</span></button>`).join('')}</nav>`;
}

function ringHtml(st) {
  if (!st) return '';
  const pct = st.state === 'resting' ? Math.round((st.since / st.minDays) * 100) : 100;
  if (st.state === 'done') return `<div class="ring done" style="--p:100%"><span><span class="n">${I.check.replace('<svg', '<svg width="24" height="24"')}</span></span></div>`;
  if (st.state === 'notStarted') return `<div class="ring" style="--p:0%"><span><span class="n">0</span><span class="u">старт</span></span></div>`;
  const left = st.state === 'resting' ? st.minDays - st.since : 0;
  const n = st.state === 'resting' ? left : st.since;
  return `<div class="ring" style="--p:${pct}%"><span><span class="n">${n}</span><span class="u">${L.plural(n, 'день', 'дня', 'дней')}</span></span></div>`;
}

function headline(plan, t) {
  const r = plan.retinoidStatuses[0];
  if (!r) return 'Сегодня';
  const n = r.item.name;
  switch (r.st.state) {
    case 'resting': return `${n} — ${L.whenWord(r.st.next, t)}`;
    case 'today': case 'overdue': return `Сегодня вечер — ${n.toLowerCase()}`;
    case 'done': return `${n} нанесён ✓`;
    default: return `${n} — можно начать сегодня`;
  }
}

function rowHtml(r, t, opts = {}) {
  const it = r.item;
  let sub = '';
  if (r.deferred) sub = `<span class="s">${esc(r.deferred)}</span>`;
  else if (r.accent) sub = `<span class="s acc">${esc(r.accent)}</span>`;
  else if (it.actives.includes('supplement')) sub = `<span class="s">${esc(suppLine(it, t, r.done))}</span>`;
  else if (r.status && L.isRetinoid(it)) sub = `<span class="s">${r.status.state === 'done' ? 'Нанесла · следующий ' + esc(L.whenWord(r.status.next, t)) : esc(L.FREQUENCIES[it.schedule.freq]?.label || '')}</span>`;
  else if (r.done && r.entry?.time) sub = `<span class="s">${r.entry.slot === 'evening' ? 'вечер' : 'утро'} · ${esc(r.entry.time)}</span>`;
  else if (it.dose) sub = `<span class="s">${esc(it.dose)}</span>`;
  const pill = r.status && !r.done ? (r.status.state === 'overdue' ? '<span class="pill due">пора</span>' : ['today', 'notStarted'].includes(r.status.state) ? '<span class="pill ret">можно</span>' : '') : '';
  const act = r.deferred ? `data-act="deferred" data-id="${it.id}" data-reason="${esc(r.deferred)}"` : `data-act="toggle" data-id="${it.id}"`;
  return `<button class="row ${r.done ? 'done' : ''} ${r.deferred ? 'deferred' : ''}" ${act} aria-pressed="${r.done}">
    <span class="chk" aria-hidden="true">${I.check}</span>
    <span class="t"><b>${dotHtml(it)}${esc(it.name)}</b>${sub}</span>${pill}</button>`;
}
function suppLine(it, t, done) {
  let streak = 0; let d = done ? t : L.addDays(t, -1);
  const days = new Set(S.entries.filter((e) => e.itemId === it.id && !e.skipped).map((e) => e.day));
  while (days.has(d)) { streak++; d = L.addDays(d, -1); }
  const yesterday = days.has(L.addDays(t, -1));
  const time = L.morningTimeFor(S.reminders, t);
  if (done) return streak > 1 ? `Выпила · ${streak} ${L.plural(streak, 'день', 'дня', 'дней')} подряд` : 'Выпила';
  const late = nowHHMM() >= time;
  const parts = [late ? 'Пора выпить' : `Напомню в ${time}`];
  if (yesterday) parts.push(streak > 1 ? `вчера ✓ · ${streak} ${L.plural(streak, 'день', 'дня', 'дней')} подряд` : 'вчера ✓');
  return parts.join(' · ');
}

function blockHtml(title, name, rows, t, meta = '') {
  if (!rows.length) return '';
  const canAll = rows.filter((r) => !r.done && !r.deferred).length > 1;
  return `<section class="block" aria-label="${esc(title)}">
    <p class="sec"><span>${title}${meta ? ` <span class="meta">${meta}</span>` : ''}</span>${canAll ? `<button class="linkbtn" data-act="mark-all" data-block="${name}">Отметить всё</button>` : ''}</p>
    ${rows.map((r) => rowHtml(r, t)).join('')}</section>`;
}

function bannersHtml() {
  const out = [];
  let snoozed = false; try { snoozed = Number(localStorage.getItem(KEY + '-banner') || 0) > Date.now(); } catch {}
  if (!isStandalone() && !ui.bannerHidden && !snoozed) {
    out.push(`<div class="banner"><span><b>Открыто во вкладке браузера.</b> Чтобы отметки не потерялись, поставь «Ритм кожи» на экран «Домой» и открывай с иконки.</span>
      <div class="acts"><button data-act="install-help">Как это сделать</button><button data-act="hide-banner">Позже</button></div></div>`);
  }
  const lastB = S.lastBackupAt ? Date.parse(S.lastBackupAt) : null;
  const firstEntry = S.entries.length ? Math.min(...S.entries.map((e) => Date.parse(e.at) || Date.now())) : null;
  if (!out.length && new Date().getHours() >= 10 && S.entries.length >= 5 && (!lastB ? (firstEntry && Date.now() - firstEntry > 3 * 864e5) : Date.now() - lastB > 7 * 864e5)) {
    out.push(`<div class="banner"><span><b>Пора сохранить копию.</b> Данные лежат только в этом телефоне — копия в «Файлах» спасёт их, если браузер очистит память.</span>
      <div class="acts"><button data-act="export">Сохранить копию</button></div></div>`);
  }
  return out.join('');
}

function todayHtml() {
  const t = today();
  const plan = L.planForDay(S, t);
  const r = plan.retinoidStatuses[0];
  const h = new Date().getHours();
  const { blocks } = plan;
  const scheduled = [...blocks.morning, ...blocks.supplements, ...blocks.evening];
  const allDone = scheduled.length > 0 && scheduled.every((x) => x.done);
  const optionalShown = blocks.optional;
  const optNames = optionalShown.slice(0, 3).map((x) => x.item.name).join(', ') + (optionalShown.length > 3 ? '…' : '');
  const st = r ? L.heroText(r.item, r.st, t) : null;
  const warm = r && ['today', 'overdue', 'notStarted', 'done'].includes(r.st.state);
  const morningFirst = h >= L.DAY_START_HOUR && h < 15;
  const order = morningFirst
    ? [blockHtml('Утро', 'morning', blocks.morning, t, esc(L.morningTimeFor(S.reminders, t))), blockHtml('Добавки', 'supplements', blocks.supplements, t), blockHtml('Вечер', 'evening', blocks.evening, t, esc(S.reminders.evening))]
    : [blockHtml('Вечер', 'evening', blocks.evening, t, esc(S.reminders.evening)), blockHtml('Утро', 'morning', blocks.morning, t, esc(L.morningTimeFor(S.reminders, t))), blockHtml('Добавки', 'supplements', blocks.supplements, t)];
  return `<main class="screen">
    <div class="dayhead"><div><p class="eyebrow">${esc(L.fmtLong(t))}</p><h1>${esc(headline(plan, t))}</h1></div><button class="addbtn" data-act="open-mark" aria-label="Отметить другое средство или другой день">${I.plus}</button></div>
    ${bannersHtml()}
    ${r ? `<button class="hero tap ${warm ? 'warm' : ''} ${r.st.state === 'overdue' ? 'due' : ''}" data-act="open-product" data-id="${r.item.id}">${ringHtml(r.st)}<span class="txt"><b>${esc(st.title)}</b><p>${esc(st.sub)}</p></span>${I.chev}</button>` : ''}
    ${allDone ? `<div class="hint ok">${I.ok}<div><p><b>На сегодня всё сделано.</b> ${r && r.st.state !== 'done' && r.st.state !== 'resting' ? '' : 'Коже — отдых.'}</p></div></div>` : ''}
    ${order.join('')}
    ${optionalShown.length ? `<section class="block">
      <button class="collapse" data-act="toggle-optional" aria-expanded="${ui.optionalOpen}"><span class="t"><b>По желанию · ${optionalShown.length}</b>${ui.optionalOpen ? '' : `<span>${esc(optNames)}</span>`}</span>${ui.optionalOpen ? I.chevDown : I.chev}</button>
      ${ui.optionalOpen ? optionalShown.map((x) => rowHtml(x, t)).join('') : ''}</section>` : ''}
    ${!scheduled.length && !optionalShown.length ? `<div class="empty">${I.empty}<p>Пока нет средств. Добавь их во вкладке «Средства».</p></div>` : ''}
  </main>`;
}

// ---------- история ----------
function historyHtml() {
  const t = today();
  const [ty, tm] = t.split('-').map(Number);
  const month = ui.histMonth || `${ty}-${String(tm).padStart(2, '0')}`;
  const [y, m] = month.split('-').map(Number);
  const first = `${month}-01`;
  const startPad = (L.weekday(first) + 6) % 7; // пн = 0
  const daysInMonth = new Date(y, m, 0).getDate();
  const sel = ui.histDay || t;
  const byDay = new Map();
  for (const e of S.entries) { if (e.skipped) continue; if (!byDay.has(e.day)) byDay.set(e.day, []); byDay.get(e.day).push(e); }
  const cells = [];
  for (let i = 0; i < startPad; i++) cells.push('<span></span>');
  for (let d = 1; d <= daysInMonth; d++) {
    const k = `${month}-${String(d).padStart(2, '0')}`;
    const es = byDay.get(k) || [];
    const its = [...new Set(es.map((e) => e.itemId))].map(itemById).filter(Boolean);
    const ret = its.some(L.isRetinoid);
    const dots = its.filter((i) => !L.isRetinoid(i)).sort((a, b) => (a.actives.includes('supplement') ? 1 : 0) - (b.actives.includes('supplement') ? 1 : 0)).slice(0, 4).map((i) => `<i class="${colorClass(i)}"></i>`).join('');
    const cls = [ret ? 'ret' : '', k === sel ? 'sel' : '', k === t ? 'today' : '', k > t ? 'future' : ''].join(' ');
    cells.push(`<button class="${cls}" data-act="hist-day" data-day="${k}" aria-label="${esc(L.fmtLong(k))}${its.length ? ': ' + esc(its.map((i) => i.name).join(', ')) : ''}">${d}<span class="dots">${dots}</span></button>`);
  }
  const prev = (() => { const d = new Date(y, m - 2, 1); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`; })();
  const next = (() => { const d = new Date(y, m, 1); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`; })();
  const selEntries = (byDay.get(sel) || []).slice().sort((a, b) => (a.slot === b.slot ? (a.time || '').localeCompare(b.time || '') : a.slot === 'morning' ? -1 : 1));
  const mag = S.items.find((i) => i.actives.includes('supplement') && !i.archived);
  const monthEnd = month === `${ty}-${String(tm).padStart(2, '0')}` ? t : `${month}-${String(daysInMonth).padStart(2, '0')}`;
  const firstMag = mag ? S.entries.filter((e) => e.itemId === mag.id && !e.skipped).map((e) => e.day).sort()[0] : null;
  const since = [first, S.startedAt, firstMag].filter(Boolean).filter((d) => d <= monthEnd).sort().pop() || first;
  const statFrom = since > first ? since : first;
  const monthDays = month > `${ty}-${String(tm).padStart(2, '0')}` || statFrom > monthEnd ? 0 : L.daysBetween(statFrom, monthEnd) + 1;
  const magCount = mag ? L.countInRange(mag.id, S.entries, statFrom, monthEnd) : 0;
  return `<main class="screen">
    <h1>История</h1>
    <div class="sec"><span>${L.MONTHS_NOM[m - 1]} ${y}</span><span style="display:flex">
      <button class="close" data-act="hist-month" data-month="${prev}" aria-label="Предыдущий месяц">${I.back}</button>
      <button class="close" data-act="hist-month" data-month="${next}" aria-label="Следующий месяц" style="transform:scaleX(-1)">${I.back}</button></span></div>
    <div class="cal">${['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'].map((d) => `<span class="h">${d}</span>`).join('')}${cells.join('')}</div>
    <div class="legend"><span><i style="background:var(--accent-soft);box-shadow:inset 0 0 0 1px var(--a-ret)"></i>ретиналь</span><span><i style="box-shadow:inset 0 0 0 1.5px var(--ctl);border-radius:50%"></i>другие средства — цветные точки</span></div>
    ${retMonth(first, monthEnd, monthDays, m)}
    ${mag && monthDays ? `<p class="small muted">${esc(mag.name)} ${statFrom > first ? 'с ' + esc(L.fmtDayMonth(statFrom)) : 'за ' + L.MONTHS_NOM[m - 1].toLowerCase()}: <b class="num" style="color:var(--ink)">${magCount} из ${monthDays}</b> ${L.plural(monthDays, 'дня', 'дней', 'дней')}</p>` : ''}
    <section class="block">
      <p class="sec"><span>${esc(L.fmtLong(sel))}</span>${sel <= t ? `<button class="linkbtn" data-act="open-mark" data-day="${sel}">Добавить</button>` : ''}</p>
      ${selEntries.length ? selEntries.map((e) => { const it = itemById(e.itemId); if (!it) return ''; return `<div class="row"><span class="t"><b>${dotHtml(it)}${esc(it.name)}</b><span class="s">${e.slot === 'evening' ? 'вечер' : 'утро'}${e.time ? ' · ' + esc(e.time) : ''}${e.overrode ? ' · вопреки подсказке' : ''}${e.fromOnboarding ? ' · указано при настройке' : ''}</span></span><button class="linkbtn" data-act="del-entry" data-id="${e.id}" aria-label="Удалить отметку ${esc(it.name)}">Удалить</button></div>`; }).join('')
        : `<div class="empty">${I.empty}<p>${sel > t ? 'Этот день ещё не наступил.' : 'В этот день отметок нет.'}</p></div>`}
    </section>
  </main>`;
}

function retMonth(first, end, monthDays, m) {
  const ret = S.items.find((i) => L.isRetinoid(i) && !i.archived);
  if (!ret || !monthDays) return '';
  const days = [...new Set(S.entries.filter((e) => e.itemId === ret.id && !e.skipped && e.day >= first && e.day <= end).map((e) => e.day))].sort();
  if (!days.length) return '';
  const minDays = L.FREQUENCIES[ret.schedule?.freq]?.minDays || 3;
  const early = days.filter((d, i) => i > 0 && L.daysBetween(days[i - 1], d) < minDays).length;
  return `<p class="small muted">${esc(ret.name)} за ${L.MONTHS_NOM[m - 1].toLowerCase()}: <b class="num" style="color:var(--ink)">${days.length}</b> ${L.plural(days.length, 'вечер', 'вечера', 'вечеров')}${early ? ` · ${early} раньше интервала` : ' · все по плану'}</p>`;
}

// ---------- средства ----------
function productsHtml() {
  const active = S.items.filter((i) => !i.archived);
  const archived = S.items.filter((i) => i.archived);
  const blockName = { morning: 'утро', evening: 'вечер', supplements: 'добавка', optional: 'по желанию' };
  const line = (i) => {
    let s = blockName[i.block] || '';
    if (L.isRetinoid(i) && i.schedule?.type === 'interval') { const st = L.intervalStatus(i, S.entries, today()); s = L.statusText(i, st, today()).title; }
    else { const last = L.lastDayOf(i.id, S.entries, today()); if (last) s += ` · последний раз ${L.whenWord(last, today())}`; }
    return `<button class="row" data-act="open-product" data-id="${i.id}"><span class="t"><b>${dotHtml(i)}${esc(i.name)}</b><span class="s">${esc(s)}</span></span>${I.chev}</button>`;
  };
  return `<main class="screen">
    <h1>Средства</h1>
    <section class="block list">${active.map(line).join('') || `<div class="empty">${I.empty}<p>Список пуст. Добавь первое средство.</p></div>`}</section>
    <button class="btn" data-act="new-product">${I.plus.replace('<svg', '<svg width="20" height="20"')} Новое средство</button>
    ${archived.length ? `<section class="block"><p class="sec"><span>В архиве</span></p>${archived.map(line).join('')}</section>` : ''}
  </main>`;
}

function weekStrip(item, st, t) {
  const start = L.addDays(t, -((L.weekday(t) + 6) % 7));
  const days = new Set(S.entries.filter((e) => e.itemId === item.id && !e.skipped).map((e) => e.day));
  const cells = [];
  for (let i = 0; i < 7; i++) {
    const k = L.addDays(start, i);
    const cls = [days.has(k) ? 'r' : '', k === t ? 'today' : '', !days.has(k) && st.next === k && k >= t ? 'plan' : ''].join(' ');
    cells.push(`<div class="${cls}"><b>${Number(k.slice(8))}</b>${['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'][L.weekday(k)]}</div>`);
  }
  return `<div class="week">${cells.join('')}</div>
    <div class="legend"><span><i style="background:var(--accent-soft);box-shadow:inset 0 0 0 1.5px var(--a-ret)"></i>нанесла</span><span><i style="box-shadow:inset 0 0 0 1.5px var(--a-ret);background:repeating-linear-gradient(135deg,transparent 0 3px,color-mix(in srgb,var(--a-ret) 25%,transparent) 3px 5px)"></i>можно снова</span><span><i style="box-shadow:inset 0 0 0 2px var(--ink)"></i>сегодня</span></div>`;
}

function productHtml(id) {
  const it = itemById(id);
  if (!it) { ui.view = null; return todayHtml(); }
  const t = today();
  const actives = it.actives.map((a) => L.ACTIVES[a]?.name).filter(Boolean).join(', ') || 'без активов';
  const blockName = { morning: 'утро', evening: 'вечер', supplements: 'добавка', optional: 'по желанию' }[it.block] || '';
  const recent = S.entries.filter((e) => e.itemId === id && !e.skipped).sort((a, b) => (a.day < b.day ? 1 : -1)).slice(0, 5);
  let statusBlock = '';
  let actions = '';
  const doneToday = S.entries.some((e) => e.itemId === id && e.day === t && !e.skipped);
  if (L.isRetinoid(it) && it.schedule?.type === 'interval') {
    const st = L.intervalStatus(it, S.entries, t);
    const stx = L.statusText(it, st, t);
    statusBlock = `<div class="card">
      <div><b style="font-size:18px">${esc(stx.title)}</b><p class="small muted">${esc(stx.sub)}</p></div>
      <div class="kv"><span class="muted small">Последний раз</span><b>${st.last ? esc(L.fmtShort(st.last)) + (st.since ? ` · ${L.daysWord(st.since)} назад` : ' · сегодня') : '—'}</b></div>
      <div class="kv"><span class="muted small">Можно снова</span><b>${esc(st.state === 'done' ? L.fmtShort(st.next) : st.state === 'resting' ? L.fmtShort(st.next) : 'сегодня')}</b></div>
      ${weekStrip(it, st, t)}</div>
      <div><p class="sec">Частота</p><div class="seg">${Object.entries(L.FREQUENCIES).map(([k, f]) => `<button data-act="set-freq" data-id="${id}" data-freq="${k}" aria-pressed="${it.schedule.freq === k}">${f.label}</button>`).join('')}</div>
      <p class="small muted" style="margin-top:8px">Не чаще раза в ${L.daysWord(L.FREQUENCIES[it.schedule.freq].minDays)}. Дни считаю сама от последнего раза — к дням недели не привязываю.</p></div>`;
    actions = doneToday
      ? `<button class="btn sec" data-act="toggle-here" data-id="${id}">Снять сегодняшнюю отметку</button>`
      : st.state === 'resting'
        ? `<div class="stack"><button class="btn sec" data-act="open-mark" data-item="${id}">Отметить за другой день</button><button class="btn sec" data-act="toggle-here" data-id="${id}">Всё равно отметить</button></div>`
        : `<div class="stack"><button class="btn ret" data-act="toggle-here" data-id="${id}">Нанесла сегодня</button><button class="btn sec" data-act="open-mark" data-item="${id}">Отметить за другой день</button></div>`;
  } else {
    actions = `<div class="stack"><button class="btn ${doneToday ? 'sec' : ''}" data-act="toggle-here" data-id="${id}">${doneToday ? 'Снять сегодняшнюю отметку' : it.actives.includes('supplement') ? 'Выпила сегодня' : 'Отметить сегодня'}</button><button class="btn sec" data-act="open-mark" data-item="${id}">Отметить за другой день</button></div>`;
  }
  return `<main class="screen">
    <div class="topbar"><button class="back" data-act="back">${I.back}Назад</button><button class="linkbtn" data-act="edit-product" data-id="${id}" style="margin-right:6px">Изменить</button></div>
    <div><h1>${esc(it.name)}</h1><p class="small muted" style="margin-top:6px">${dotHtml(it)}${esc(actives)}${blockName && blockName.toLowerCase() !== actives.toLowerCase() ? ' · ' + esc(blockName) : ''}${it.dose ? ' · ' + esc(it.dose) : ''}</p></div>
    ${statusBlock}
    ${actions}
    <section class="block"><p class="sec">Статистика</p>
      <div class="stat"><span>За 7 дней</span><b class="num">${L.countInRange(id, S.entries, L.addDays(t, -6), t)}</b></div>
      <div class="stat"><span>За 30 дней</span><b class="num">${L.countInRange(id, S.entries, L.addDays(t, -29), t)}</b></div></section>
    <section class="block"><p class="sec">Последние отметки</p>
      ${recent.length ? recent.map((e) => `<div class="row"><span class="t"><b class="num" style="font-size:15px">${esc(L.fmtShort(e.day))}</b><span class="s">${e.slot === 'evening' ? 'вечер' : 'утро'}${e.time ? ' · ' + esc(e.time) : ''}${e.fromOnboarding ? ' · указано при настройке' : ''}</span></span><button class="linkbtn" data-act="del-entry" data-id="${e.id}">Удалить</button></div>`).join('') : '<p class="muted small">Отметок пока нет.</p>'}
    </section>
  </main>`;
}

function editHtml(id) {
  const isNew = id === 'new';
  const d = ui.draft;
  const blocks = [['morning', 'Утро'], ['evening', 'Вечер'], ['supplements', 'Добавка'], ['optional', 'По желанию']];
  const det = L.detectActives(d.composition || '');
  const comp = d.composition ? highlight(d.composition, det.matches) : '';
  const conflicts = L.conflictsPreview(d.actives, { ...S, items: S.items.filter((i) => i.id !== d.id) });
  const isRet = d.actives.includes('retinoid');
  return `<main class="screen">
    <div class="topbar"><button class="back" data-act="back">${I.back}Назад</button></div>
    <h1>${isNew ? 'Новое средство' : 'Изменить'}</h1>
    <div class="field"><label for="e-name">Название</label><input id="e-name" value="${esc(d.name)}" placeholder="Например, тонер с гликолевой кислотой" data-input="e-name" autocomplete="off"></div>
    <div><p class="sec"><span>Состав <span class="meta">необязательно</span></span></p>
      <div class="field"><label for="e-comp">Вставь текст с упаковки</label><textarea id="e-comp" data-input="e-comp" placeholder="Aqua, Glycolic Acid, Niacinamide…">${esc(d.composition || '')}</textarea></div>
      <p class="small muted" style="margin-top:8px">Сфотографируй состав, зажми текст на фото и нажми «Скопировать» — iPhone распознаёт его сам. Потом вставь сюда.</p>
      ${comp ? `<div class="composition" style="margin-top:8px" aria-label="Найденные активы подсвечены">${comp}</div>` : ''}</div>
    <div><p class="sec">Активы ${det.actives.length ? '<span class="meta">нашла в составе</span>' : ''}</p>
      <div class="chips">${Object.entries(L.ACTIVES).map(([k, a]) => `<button class="chip" data-act="e-active" data-active="${k}" aria-pressed="${d.actives.includes(k)}"><i class="dot c-${a.color}${L.ACID_GROUP.includes(k) ? ' ring-dot' : ''}"></i>${esc(a.name)}</button>`).join('')}</div></div>
    ${conflicts.length ? `<div class="hint">${I.drop}<div>${conflicts.map((c) => `<p>${esc(c)}</p>`).join('')}</div></div>` : ''}
    <div><p class="sec">Когда</p><div class="seg">${blocks.map(([k, l]) => `<button data-act="e-block" data-block="${k}" aria-pressed="${d.block === k}">${l}</button>`).join('')}</div>
      <p class="small muted" style="margin-top:8px">${d.block === 'optional' ? 'Будет в свёрнутом списке «По желанию» — отмечаешь, когда используешь.' : 'Будет каждый день в этом блоке на экране «Сегодня».'}</p></div>
    ${isRet ? `<div><p class="sec">Частота</p><div class="seg">${Object.entries(L.FREQUENCIES).map(([k, f]) => `<button data-act="e-freq" data-freq="${k}" aria-pressed="${(d.freq || '2w') === k}">${f.label}</button>`).join('')}</div></div>` : ''}
    ${d.block === 'supplements' ? `<div class="field"><label for="e-dose">Дозировка</label><input id="e-dose" value="${esc(d.dose || '')}" placeholder="Например, 1 капсула" data-input="e-dose"></div>` : ''}
    <button class="btn" data-act="e-save" ${d.name.trim() ? '' : 'disabled'}>${isNew ? 'Добавить' : 'Сохранить'}</button>
    ${!isNew ? `<button class="btn sec" data-act="e-archive">${itemById(id)?.archived ? 'Вернуть из архива' : 'В архив'}</button><button class="btn danger" data-act="e-delete">Удалить вместе с отметками</button>` : ''}
  </main>`;
}
function highlight(text, matches) {
  let out = ''; let pos = 0;
  for (const m of matches) { if (m.index < pos) continue; out += esc(text.slice(pos, m.index)) + `<mark>${esc(text.slice(m.index, m.index + m.word.length))}</mark>`; pos = m.index + m.word.length; }
  return out + esc(text.slice(pos));
}

// ---------- ещё ----------
function moreHtml() {
  const r = S.reminders;
  return `<main class="screen">
    <h1>Ещё</h1>
    <button class="row" data-act="open-reminders"><span class="t"><b>Напоминания</b><span class="s">Утро ${esc(r.morning.weekdays)} (будни), ${esc(r.morning.weekend)} (выходные) · вечер ${esc(r.evening)}</span></span>${I.chev}</button>
    <section class="block"><p class="sec">Правила</p>
      ${L.RULES.map((rule) => `<div class="row"><span class="t"><b>${esc(rule.text)}</b>${rule.sub ? `<span class="s">${esc(rule.sub)}</span>` : ''}</span><button class="toggle" role="switch" aria-checked="${S.rules[rule.id] !== false}" aria-label="${esc(rule.text)}" data-act="rule" data-id="${rule.id}"></button></div>`).join('')}
      <p class="small muted" style="padding-top:8px">Правила — подсказки, а не запреты. Числа и сочетания лучше сверить с косметологом.</p></section>
    <section class="block"><p class="sec">Данные</p>
      <div class="row"><span class="t"><b>Хранятся только на этом iPhone</b><span class="s">${S.lastBackupAt ? 'Последняя копия: ' + esc(new Date(S.lastBackupAt).toLocaleString('ru-RU', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })) : 'Копию ещё не сохраняла'}</span></span></div>
      <button class="row" data-act="export"><span class="t"><b>Сохранить копию в Файлы</b><span class="s">JSON-файл со всеми средствами и отметками</span></span>${I.chev}</button>
      <label class="row" style="cursor:pointer"><span class="t"><b>Восстановить из копии</b><span class="s">Заменит текущие данные</span></span>${I.chev}<input type="file" accept="application/json,.json" class="sr" data-change="import" id="import-file"></label>
      <button class="row" data-act="reset"><span class="t"><b style="color:var(--warn)">Начать заново</b><span class="s">Удалит отметки и вернёт стартовый набор</span></span></button>
    </section>
    <p class="ver">Ритм кожи ${VERSION} · прототип</p>
  </main>`;
}

function remindersHtml() {
  const r = S.reminders;
  const t = today();
  const tomorrow = L.addDays(t, 1);
  const overrides = Object.entries(r.overrides || {}).filter(([k]) => k >= t).sort();
  return `<main class="screen">
    <div class="topbar"><button class="back" data-act="back">${I.back}Ещё</button></div>
    <h1>Напоминания</h1>
    <section class="block"><p class="sec">Утро: уход и магний</p>
      <div class="row"><span class="t"><b>Будни</b></span><input class="timein" type="time" value="${esc(r.morning.weekdays)}" data-change="r-weekdays" aria-label="Время утром в будни"></div>
      <div class="row"><span class="t"><b>Выходные</b></span><input class="timein" type="time" value="${esc(r.morning.weekend)}" data-change="r-weekend" aria-label="Время утром в выходные"></div>
      ${overrides.map(([k, v]) => `<div class="row"><span class="t"><b>${esc(L.fmtShort(k))}</b><span class="s">разово</span></span><input class="timein" type="time" value="${esc(v)}" data-change="r-override" data-day="${k}" aria-label="Разовое время ${esc(L.fmtShort(k))}"><button class="close" data-act="r-del-override" data-day="${k}" aria-label="Убрать разовое время">${I.close}</button></div>`).join('')}
      ${r.overrides?.[tomorrow] ? '' : `<button class="row" data-act="r-add-override" data-day="${tomorrow}"><span class="t"><b>Завтра в другое время</b><span class="s">${esc(L.fmtShort(tomorrow))} — например, ранний выезд</span></span>${I.plus.replace('<svg', '<svg width="22" height="22"')}</button>`}
    </section>
    <section class="block"><p class="sec">Вечер</p>
      <div class="row"><span class="t"><b>Каждый день</b></span><input class="timein" type="time" value="${esc(r.evening)}" data-change="r-evening" aria-label="Время вечером"></div></section>
    <div class="hint ok">${I.ok}<div><p><b>Как это работает.</b> Веб-приложение не умеет само присылать уведомления, поэтому напоминания встают в Календарь iPhone с будильником. В событии есть ссылка на «Ритм кожи».</p></div></div>
    <a class="btn" data-act="ics" href="${icsDataUrl()}" download="ritm-kozhi.ics" style="text-decoration:none">Добавить в Календарь</a>
    <p class="small muted">Откроется Календарь с событиями — нажми «Добавить все». Поменяла время — добавь ещё раз, а старые события удали.</p>
    <a class="btn sec" href="ritm-kozhi-default.ics" style="text-decoration:none">Запасной вариант: 7:45 · 9:30 · 22:00</a>
    <p class="small muted">Если кнопка выше не открыла Календарь, нажми запасную: это обычный файл, Safari его точно откроет. Ещё можно открыть ${esc(APP_URL.replace(/^https?:\/\//, ''))} в Safari и нажать «Добавить в Календарь» там.</p>
  </main>`;
}

const BLOCK_LABEL = { morning: 'утро', evening: 'вечер', optional: 'по желанию', supplements: 'добавка' };

// ---------- онбординг ----------
function onboardingHtml() {
  const s = ui.obStep; const o = ui.ob;
  const steps = `<div class="steps">${[0, 1, 2, 3].map((i) => `<i class="${i <= s ? 'on' : ''}"></i>`).join('')}</div>`;
  const t = today();
  const backBtn = s > 0 && s < 4 ? `<button class="back" data-act="ob-back" style="margin-left:-10px">${I.back}Назад</button>` : '<span></span>';
  if (s === 0) {
    const sel = o.items || Object.fromEntries(S.items.map((i) => [i.id, true]));
    o.items = sel;
    return `<main class="screen no-tabs">${steps}
      <div><p class="eyebrow">Шаг 1 из 4</p><h1>Что у тебя на полке?</h1><p class="muted" style="margin-top:8px">Это твой набор. Сними галочку с того, чем не пользуешься, — потом можно добавить новое.</p></div>
      <section class="block">${S.items.map((i) => { const blk = (o.blocks || {})[i.id] || i.block; const fixed = L.isRetinoid(i) || i.block === 'supplements'; return `<div class="row ${sel[i.id] ? 'done' : ''}"><button class="chk" data-act="ob-item" data-id="${i.id}" aria-pressed="${!!sel[i.id]}" aria-label="${esc(i.name)}: ${sel[i.id] ? 'в наборе' : 'не использую'}">${I.check}</button><span class="t"><b>${dotHtml(i)}${esc(i.name)}</b><span class="s">${esc(i.actives.map((a) => L.ACTIVES[a]?.name).join(', ') || 'без активов')}</span></span>${sel[i.id] && !fixed ? `<button class="blockpick" data-act="ob-block" data-id="${i.id}" aria-label="Когда: ${BLOCK_LABEL[blk]}. Нажми, чтобы сменить">${BLOCK_LABEL[blk]}</button>` : ''}</div>`; }).join('')}</section>
      <p class="small muted">Справа — когда средство показывать: утро, вечер или «по желанию» (свёрнутый список, отмечаешь, когда используешь).</p>
      <button class="btn" data-act="ob-next">Дальше</button></main>`;
  }
  if (s === 1) {
    const opts = [['1', 'Вчера'], ['3', '2–3 дня назад'], ['7', 'Неделю назад'], ['date', 'Выбрать дату…'], ['never', 'Ещё не начинала']];
    return `<main class="screen no-tabs">${steps}<div class="topbar">${backBtn}</div>
      <div><p class="eyebrow">Шаг 2 из 4</p><h1>Когда последний раз был ретиналь?</h1><p class="muted" style="margin-top:8px">Посчитаю, когда можно снова. Не помнишь точно — выбери примерно, потом поправим.</p></div>
      <div class="stack">${opts.map(([k, l]) => `<button class="opt" data-act="ob-last" data-v="${k}" aria-pressed="${o.last === k}">${l}${o.last === k && k !== 'never' && k !== 'date' ? `<span class="pill ret">${esc(L.fmtDayMonth(L.addDays(t, -Number(k))))}</span>` : ''}</button>`).join('')}</div>
      ${o.last === 'date' ? `<div class="field"><label for="ob-date">Дата</label><input id="ob-date" type="date" max="${t}" value="${o.date || L.addDays(t, -4)}" data-change="ob-date"></div>` : ''}
      <button class="btn" data-act="ob-next" ${o.last ? '' : 'disabled'}>Дальше</button></main>`;
  }
  if (s === 2) {
    const f = o.freq || '2w';
    return `<main class="screen no-tabs">${steps}<div class="topbar">${backBtn}</div>
      <div><p class="eyebrow">Шаг 3 из 4</p><h1>Как часто теперь?</h1><p class="muted" style="margin-top:8px">Ты говорила, что переходишь с 1 на 2 раза в неделю. Поменять можно в любой момент.</p></div>
      <div class="stack">${Object.entries(L.FREQUENCIES).map(([k, fr]) => `<button class="opt" data-act="ob-freq" data-v="${k}" aria-pressed="${f === k}">${fr.label}<span class="small muted">раз в ${L.daysWord(fr.minDays)}</span></button>`).join('')}</div>
      <button class="btn" data-act="ob-next">Дальше</button></main>`;
  }
  if (s === 3) {
    const r = o.rem || { weekdays: S.reminders.morning.weekdays, weekend: S.reminders.morning.weekend, evening: S.reminders.evening };
    o.rem = r;
    return `<main class="screen no-tabs">${steps}<div class="topbar">${backBtn}</div>
      <div><p class="eyebrow">Шаг 4 из 4</p><h1>Когда напоминать?</h1><p class="muted" style="margin-top:8px">Утром — уход и магний, вечером — вечерний уход.</p></div>
      <section class="block">
        <div class="row"><span class="t"><b>Утро в будни</b></span><input class="timein" type="time" value="${esc(r.weekdays)}" data-change="ob-weekdays" aria-label="Утро в будни"></div>
        <div class="row"><span class="t"><b>Утро в выходные</b></span><input class="timein" type="time" value="${esc(r.weekend)}" data-change="ob-weekend" aria-label="Утро в выходные"></div>
        <div class="row"><span class="t"><b>Вечер</b></span><input class="timein" type="time" value="${esc(r.evening)}" data-change="ob-evening" aria-label="Вечер"></div>
      </section>
      <p class="small muted">Разовый сдвиг («завтра в 7:15») — в «Ещё → Напоминания».</p>
      <button class="btn" data-act="ob-next">Посмотреть мою неделю</button></main>`;
  }
  // итог — aha-экран
  const preview = obPreviewState();
  const ret = preview.items.find((i) => i.id === 'retinal');
  const st = ret ? L.intervalStatus(ret, preview.entries, t) : null;
  const next = st ? (st.state === 'resting' ? st.next : t) : null;
  const S0 = S; S = preview; const strip = ret && st ? weekStrip(ret, st, t) : ''; S = S0;
  return `<main class="screen no-tabs">
    <div><p class="eyebrow">Готово</p><h1>${ret ? (next === t ? 'Ретиналь можно сегодня вечером' : `Ретиналь можно ${L.whenWord(next, t)}, ${L.fmtDayMonth(next)}`) : 'Всё готово'}</h1></div>
    ${ret ? `<div class="card">${strip}</div>` : ''}
    <section class="block"><p class="sec">Что я беру на себя</p>
      <div class="row"><span class="t"><b>${dotHtml({ actives: ['retinoid'] })}Интервал ретиналя</b><span class="s">Скажу, отдыхает он или пора — каждый день на «Сегодня».</span></span></div>
      <div class="row"><span class="t"><b>${dotHtml({ actives: ['azelaic'] })}Азелаиновую — в другие вечера</b><span class="s">В вечер ретиналя предложу её перенести.</span></span></div>
      <div class="row"><span class="t"><b>${dotHtml({ actives: ['spf'] })}SPF после ретиналя</b><span class="s">Утром напомню, что кожа чувствительнее к солнцу.</span></span></div>
      <div class="row"><span class="t"><b>${dotHtml({ actives: ['supplement'] })}Магний</b><span class="s">Отметка в один тап и серия дней подряд.</span></span></div>
    </section>
    <button class="btn ret" data-act="ob-finish">Начать</button>
    <button class="btn sec" data-act="ob-back">Назад</button></main>`;
}
function obPreviewState() {
  const o = ui.ob; const t = today();
  const st = JSON.parse(JSON.stringify(S));
  st.items.forEach((i) => { i.archived = !(o.items ? o.items[i.id] : true); const b = o.blocks?.[i.id]; if (b) { i.block = b; i.schedule = b === 'optional' ? { type: 'asneeded' } : { type: 'daily' }; } });
  const ret = st.items.find((i) => i.id === 'retinal');
  if (ret) ret.schedule.freq = o.freq || '2w';
  st.entries = st.entries.filter((e) => !e.fromOnboarding);
  let day = null;
  if (o.last && o.last !== 'never') day = o.last === 'date' ? (o.date || L.addDays(t, -4)) : L.addDays(t, -Number(o.last));
  if (day && ret) st.entries.push({ id: L.uid(), itemId: 'retinal', day, slot: 'evening', at: new Date().toISOString(), time: null, fromOnboarding: true });
  if (o.rem) st.reminders = { ...st.reminders, morning: { weekdays: o.rem.weekdays, weekend: o.rem.weekend }, evening: o.rem.evening };
  return st;
}

// ---------- экспорт / импорт / ics ----------
async function exportData() {
  const data = JSON.stringify({ ...S, exportedAt: new Date().toISOString(), app: 'ritm-kozhi' }, null, 2);
  const name = `ritm-kozhi-${today()}.json`;
  const file = new File([data], name, { type: 'application/json' });
  try {
    if (navigator.canShare?.({ files: [file] })) { await navigator.share({ files: [file], title: 'Копия «Ритма кожи»' }); }
    else downloadBlob(file, name);
    S.lastBackupAt = new Date().toISOString(); save(); toast('Копия сохранена'); render();
  } catch (e) { if (e.name !== 'AbortError') { downloadBlob(file, name); S.lastBackupAt = new Date().toISOString(); save(); render(); } }
}
function downloadBlob(blob, name) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}
async function importData(file) {
  try {
    const obj = JSON.parse(await file.text());
    const next = L.validateImport(obj);
    openSheet({ type: 'confirm', title: 'Восстановить копию?', text: `В копии ${next.items.length} средств и ${next.entries.length} отметок. Текущие данные будут заменены.`, yes: 'Восстановить', fn: () => { S = { ...next, onboarded: true }; save(); toast('Копия восстановлена'); render(); } });
  } catch (e) { toast(e instanceof SyntaxError ? 'Файл повреждён или это не JSON.' : e.message); }
}
function icsDataUrl() {
  return 'data:text/calendar;charset=utf-8,' + encodeURIComponent(L.buildIcs(S.reminders, today(), APP_URL));
}

// ---------- события ----------
document.addEventListener('click', (ev) => {
  const el = ev.target.closest('[data-act]');
  if (!el) return;
  const a = el.dataset.act; const id = el.dataset.id;
  const t = today();
  switch (a) {
    case 'tab': ui.tab = el.dataset.tab; ui.view = null; if (ui.tab === 'history') ui.histDay = null; render(); scrollTo(0, 0); break;
    case 'toggle': toggleRow(id); break;
    case 'toggle-here': toggleRow(id); break;
    case 'deferred': openSheet({ type: 'deferred', itemId: id, reason: deferredReason(id, el.dataset.reason) }); break;
    case 'force-mark-today': { const it = itemById(id); const slot = L.isRetinoid(it) ? 'evening' : L.defaultSlot(it); const flag = L.checkMark({ itemId: id, day: t, slot }, S).length > 0; const e = addEntry(id, t, slot, flag); closeSheet(); markedToast(e); render(); break; }
    case 'mark-slot': { const e = addEntry(id, t, el.dataset.slot); closeSheet(); markedToast(e); render(); break; }
    case 'force-mark': { const s = ui.sheet; const e = addEntry(s.itemId, s.day, s.slot, true); closeSheet(); markedToast(e); s.after?.(); render(); break; }
    case 'mark-all': markAll(el.dataset.block); break;
    case 'toggle-optional': ui.optionalOpen = !ui.optionalOpen; render(); break;
    case 'open-mark': { const item = el.dataset.item || S.items.find((i) => !i.archived)?.id; const day = el.dataset.day || t; openSheet({ type: 'mark', itemId: item, day, slot: L.defaultSlot(itemById(item)) }); break; }
    case 'm-day': ui.sheet.day = el.dataset.day; ui.sheet.showDate = false; renderSheet(); break;
    case 'm-day-custom': ui.sheet.showDate = true; renderSheet(); break;
    case 'm-slot': ui.sheet.slot = el.dataset.slot; renderSheet(); break;
    case 'm-save': { const s = ui.sheet; const e = addEntry(s.itemId, s.day, s.slot, !!el.dataset.force); closeSheet(); markedToast(e); ui.histDay = s.day; render(); break; }
    case 'close-sheet': closeSheet(); break;
    case 'confirm-yes': { const fn = ui.sheet.fn; closeSheet(); fn(); break; }
    case 'toast-action': { const fn = ui.toast?.action?.fn; ui.toast = null; renderToast(); fn?.(); break; }
    case 'open-product': ui.view = 'product'; ui.param = id; render(); scrollTo(0, 0); break;
    case 'back': if (ui.view === 'edit' && ui.param !== 'new') { ui.view = 'product'; } else { ui.view = null; } render(); scrollTo(0, 0); break;
    case 'set-freq': itemById(id).schedule.freq = el.dataset.freq; save(); render(); toast(`Частота: ${L.FREQUENCIES[el.dataset.freq].label.toLowerCase()}`); break;
    case 'hist-day': ui.histDay = el.dataset.day; render(); break;
    case 'hist-month': ui.histMonth = el.dataset.month; ui.histDay = `${el.dataset.month}-01`; render(); break;
    case 'del-entry': { const e = removeEntry(id); toast('Отметка удалена', { label: 'Вернуть', fn: () => { S.entries.push(e); save(); render(); } }); render(); break; }
    case 'new-product': ui.draft = { id: null, name: '', composition: '', actives: [], block: 'optional', freq: '2w', dose: '' }; ui.view = 'edit'; ui.param = 'new'; render(); scrollTo(0, 0); break;
    case 'edit-product': { const it = itemById(id); ui.draft = { id, name: it.name, composition: it.composition || '', actives: [...it.actives], block: it.block, freq: it.schedule?.freq || '2w', dose: it.dose || '' }; ui.view = 'edit'; ui.param = id; render(); scrollTo(0, 0); break; }
    case 'e-active': { const k = el.dataset.active; const d = ui.draft; d.actives = d.actives.includes(k) ? d.actives.filter((x) => x !== k) : [...d.actives, k]; d.activesTouched = true; render(); break; }
    case 'e-block': ui.draft.block = el.dataset.block; render(); break;
    case 'e-freq': ui.draft.freq = el.dataset.freq; render(); break;
    case 'e-save': saveDraft(); break;
    case 'e-archive': { const it = itemById(ui.param); it.archived = !it.archived; save(); toast(it.archived ? 'Перенесено в архив' : 'Вернула из архива'); ui.view = null; ui.tab = 'products'; render(); break; }
    case 'e-delete': { const pid = ui.param; const it = itemById(pid); openSheet({ type: 'confirm', title: `Удалить «${it.name}»?`, text: 'Средство и все его отметки исчезнут. Если просто перестала пользоваться — лучше в архив.', yes: 'Удалить', fn: () => { S.items = S.items.filter((i) => i.id !== pid); S.entries = S.entries.filter((e) => e.itemId !== pid); save(); ui.view = null; ui.tab = 'products'; render(); } }); break; }
    case 'rule': S.rules[id] = !(S.rules[id] !== false); save(); render(); break;
    case 'open-reminders': ui.view = 'reminders'; render(); scrollTo(0, 0); break;
    case 'r-add-override': S.reminders.overrides = { ...(S.reminders.overrides || {}), [el.dataset.day]: '07:15' }; save(); render(); break;
    case 'ics': el.href = icsDataUrl(); return;
    case 'r-del-override': delete S.reminders.overrides[el.dataset.day]; save(); render(); break;
    case 'export': exportData(); break;
    case 'reset': openSheet({ type: 'confirm', title: 'Начать заново?', text: 'Все отметки удалятся, набор вернётся к стартовому. Сначала лучше сохранить копию.', yes: 'Удалить всё и начать заново', fn: () => { S = L.seedState(); save(); ui.obStep = 0; ui.ob = {}; render(); } }); break;
    case 'install-help': openSheet({ type: 'install' }); break;
    case 'hide-banner': ui.bannerHidden = true; try { localStorage.setItem(KEY + '-banner', String(Date.now() + 3 * 864e5)); } catch {} render(); break;
    // онбординг
    case 'ob-item': ui.ob.items[id] = !ui.ob.items[id]; render(); break;
    case 'ob-block': { const cur = (ui.ob.blocks || {})[id] || itemById(id).block; const order = ['morning', 'evening', 'optional']; ui.ob.blocks = { ...(ui.ob.blocks || {}), [id]: order[(order.indexOf(cur) + 1) % 3] }; render(); break; }
    case 'ob-last': ui.ob.last = el.dataset.v; render(); break;
    case 'ob-freq': ui.ob.freq = el.dataset.v; render(); break;
    case 'ob-next': ui.obStep++; render(); scrollTo(0, 0); break;
    case 'ob-back': ui.obStep = Math.max(0, ui.obStep - 1); render(); break;
    case 'ob-finish': { const p = obPreviewState(); S = { ...p, onboarded: true, startedAt: today() }; save(); askPersist(); ui.tab = 'today'; render(); scrollTo(0, 0); break; }
  }
});
function deferredReason(id, short) {
  const it = itemById(id); const t = today();
  if (L.isRetinoid(it)) { const st = L.intervalStatus(it, S.entries, t); return `Ретиналь был ${L.whenWord(st.last, t)}. При частоте «${L.FREQUENCIES[it.schedule.freq].label.toLowerCase()}» следующий — ${L.whenWord(st.next, t)}.`; }
  if (it.actives.includes('azelaic')) return 'Сегодня вечер ретиналя — азелаиновую лучше в другой вечер, так коже спокойнее. Утром можно.';
  return short;
}
function saveDraft() {
  const d = ui.draft;
  const isNew = ui.param === 'new';
  const schedule = d.actives.includes('retinoid') ? { type: 'interval', freq: d.freq || '2w' } : d.block === 'optional' ? { type: 'asneeded' } : { type: 'daily' };
  const block = d.actives.includes('retinoid') && d.block !== 'optional' ? 'evening' : d.block;
  if (isNew) {
    const it = { id: L.uid(), name: d.name.trim(), actives: d.actives, block, schedule, composition: d.composition, dose: d.dose, archived: false };
    S.items.push(it); save(); toast('Средство добавлено'); ui.view = 'product'; ui.param = it.id;
  } else {
    Object.assign(itemById(ui.param), { name: d.name.trim(), actives: d.actives, block, schedule, composition: d.composition, dose: d.dose });
    save(); toast('Сохранено'); ui.view = 'product';
  }
  render(); scrollTo(0, 0);
}

document.addEventListener('input', (ev) => {
  const k = ev.target.dataset.input;
  if (!k) return;
  const d = ui.draft;
  if (k === 'e-name') { d.name = ev.target.value; document.querySelector('[data-act="e-save"]').disabled = !d.name.trim(); }
  if (k === 'e-dose') d.dose = ev.target.value;
  if (k === 'e-comp') {
    d.composition = ev.target.value;
    clearTimeout(d.t);
    d.t = setTimeout(() => {
      const det = L.detectActives(d.composition);
      if (!d.activesTouched || !d.actives.length) d.actives = det.actives;
      else d.actives = [...new Set([...d.actives, ...det.actives])];
      const pos = ev.target.selectionStart; render();
      const ta = document.getElementById('e-comp'); if (ta) { ta.focus(); try { ta.setSelectionRange(pos, pos); } catch {} }
    }, 500);
  }
});
document.addEventListener('change', (ev) => {
  const k = ev.target.dataset.change; const v = ev.target.value;
  if (!k) return;
  const R = S.reminders;
  switch (k) {
    case 'm-item': ui.sheet.itemId = v; ui.sheet.slot = L.defaultSlot(itemById(v)); renderSheet(); break;
    case 'm-date': if (v) { ui.sheet.day = v > today() ? today() : v; renderSheet(); } break;
    case 'r-weekdays': if (v) { R.morning.weekdays = v; save(); render(); toast('Время сохранено'); } break;
    case 'r-weekend': if (v) { R.morning.weekend = v; save(); render(); toast('Время сохранено'); } break;
    case 'r-evening': if (v) { R.evening = v; save(); render(); toast('Время сохранено'); } break;
    case 'r-override': if (v) { R.overrides[ev.target.dataset.day] = v; save(); render(); toast('Время сохранено'); } break;
    case 'import': if (ev.target.files?.[0]) importData(ev.target.files[0]); ev.target.value = ''; break;
    case 'ob-date': ui.ob.date = v; break;
    case 'ob-weekdays': ui.ob.rem.weekdays = v || ui.ob.rem.weekdays; break;
    case 'ob-weekend': ui.ob.rem.weekend = v || ui.ob.rem.weekend; break;
    case 'ob-evening': ui.ob.rem.evening = v || ui.ob.rem.evening; break;
  }
});
document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && ui.sheet) closeSheet(); });
let swipeY = null;
document.addEventListener('touchstart', (ev) => { const sh = ev.target.closest('.sheet'); swipeY = sh && (ev.target.closest('.grab, .head') || sh.scrollTop === 0) ? ev.touches[0].clientY : null; }, { passive: true });
document.addEventListener('touchmove', (ev) => { if (swipeY != null && ev.touches[0].clientY - swipeY > 90 && ui.sheet) { swipeY = null; closeSheet(); } }, { passive: true });

// новый день, возврат в приложение
let lastDay = today();
document.addEventListener('visibilitychange', () => { if (!document.hidden && today() !== lastDay) { lastDay = today(); render(); } });
setInterval(() => { if (today() !== lastDay) { lastDay = today(); render(); } }, 60000);

// запуск
render();
if (S.onboarded) askPersist();
if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) navigator.serviceWorker.register('./sw.js').catch(() => {});
window.__ritm = { get state() { return S; }, set state(v) { S = v; save(); render(); }, ui, render, L };
