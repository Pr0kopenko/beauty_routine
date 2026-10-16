// Распознавание средства по фото через Claude или ChatGPT с ключом пользователя.
// Ключ хранится только в localStorage этого устройства и не попадает в копию данных.

import { ACTIVES, RETINOID_FORMS, PRODUCT_TYPES } from './logic.js';

const AI_KEY = 'ritm-kozhi-ai';

export const PROVIDERS = {
  claude: { label: 'Claude', models: [['claude-haiku-5-5', 'Haiku 5.5 — быстро и дёшево'], ['claude-sonnet-5-5', 'Sonnet 5.5 — точнее']], keyHint: 'sk-ant-…', console: 'https://platform.claude.com/settings/keys' },
  openai: { label: 'ChatGPT', models: [['gpt-6-astra', 'gpt-6-astra']], keyHint: 'sk-…', console: 'https://platform.openai.com/api-keys' },
};

export function loadAiSettings() {
  try { return { provider: 'claude', model: 'claude-haiku-5-5', key: '', ...JSON.parse(localStorage.getItem(AI_KEY) || '{}') }; }
  catch { return { provider: 'claude', model: 'claude-haiku-5-5', key: '' }; }
}
export function saveAiSettings(s) { try { localStorage.setItem(AI_KEY, JSON.stringify(s)); } catch {} }
export const aiReady = (s = loadAiSettings()) => !!s.key?.trim();

// ---------- картинки ----------

/** Уменьшает фото до max по длинной стороне. Возвращает { base64, dataUrl, width, height }. */
export async function resizeImage(file, max = 1280, quality = 0.85) {
  const bmp = await loadBitmap(file);
  const scale = Math.min(1, max / Math.max(bmp.width, bmp.height));
  const w = Math.round(bmp.width * scale), h = Math.round(bmp.height * scale);
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  c.getContext('2d').drawImage(bmp, 0, 0, w, h);
  const dataUrl = c.toDataURL('image/jpeg', quality);
  return { dataUrl, base64: dataUrl.split(',')[1], width: w, height: h };
}
export async function imageBlob(file, max = 1600, quality = 0.85) {
  const bmp = await loadBitmap(file);
  const scale = Math.min(1, max / Math.max(bmp.width, bmp.height));
  const c = document.createElement('canvas'); c.width = Math.round(bmp.width * scale); c.height = Math.round(bmp.height * scale);
  c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
  return new Promise((res) => c.toBlob(res, 'image/jpeg', quality));
}
async function loadBitmap(file) {
  if (window.createImageBitmap) { try { return await createImageBitmap(file, { imageOrientation: 'from-image' }); } catch {} }
  return new Promise((res, rej) => { const img = new Image(); img.onload = () => res(img); img.onerror = () => rej(new Error('Не получилось открыть фото.')); img.src = URL.createObjectURL(file); });
}

// ---------- запрос ----------

const activeIds = Object.keys(ACTIVES);
const SCHEMA = {
  type: 'object',
  properties: {
    is_skincare: { type: 'boolean' },
    brand: { type: 'string' },
    name: { type: 'string' },
    product_type: { type: 'string', enum: Object.keys(PRODUCT_TYPES) },
    actives: { type: 'array', items: { type: 'string', enum: activeIds } },
    retinoid_form: { type: 'string', enum: ['none', ...Object.keys(RETINOID_FORMS)] },
    strength: { type: 'string' },
    time_of_day: { type: 'string', enum: ['morning', 'evening', 'any'] },
    inci_text: { type: 'string' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    note_ru: { type: 'string' },
  },
  required: ['is_skincare', 'brand', 'name', 'product_type', 'actives', 'retinoid_form', 'strength', 'time_of_day', 'inci_text', 'confidence', 'note_ru'],
  additionalProperties: false,
};

const PROMPT = `Ты помогаешь вести трекер ухода за кожей. На фото — косметическое средство или БАД (упаковка, флакон или состав на обороте).
Определи:
- brand, name — бренд и название как на упаковке (латиницей, если так написано). Если не видно — твоя лучшая догадка по дизайну, и confidence "low".
- product_type — один из: ${Object.entries(PRODUCT_TYPES).map(([k, v]) => `${k} (${v})`).join(', ')}.
- actives — активные компоненты из списка: ${activeIds.map((k) => `${k} (${ACTIVES[k].name})`).join(', ')}. Бери из видимого состава (INCI) или из заявленного на упаковке; если состав не виден — из того, что ты знаешь об этом продукте. Не добавляй то, в чём не уверена. «Citric acid» в конце состава — регулятор pH, не AHA.
- retinoid_form — если есть ретиноид: retinyl_esters, retinol, retinal, hpr, adapalene, tretinoin, tazarotene, bakuchiol не ретиноид. Иначе "none".
- strength — концентрация главного актива, если указана (например "0.1%"), иначе "".
- time_of_day — morning для SPF, evening для ретиноидов и сильных кислот, иначе any.
- inci_text — состав, если он читается на фото (можно сокращённо), иначе "".
- note_ru — 1 короткое предложение по-русски: что это и как обычно используют.
Если на фото не уход и не БАД — is_skincare=false.`;

export async function recognizeProduct(file, settings = loadAiSettings()) {
  if (!aiReady(settings)) throw new AiError('no-key', 'Добавь ключ ИИ в «Ещё → Распознавание».');
  const img = await resizeImage(file, 1280);
  let raw;
  if (settings.provider === 'openai') raw = await callOpenAI(settings, img.base64);
  else raw = await callClaude(settings, img.base64);
  return { ...normalize(raw), thumb: await thumbFromDataUrl(img.dataUrl) };
}

export async function testKey(settings) {
  if (settings.provider === 'openai') {
    const r = await post('https://api.openai.com/v1/responses', { authorization: `Bearer ${settings.key}` }, { model: settings.model, input: 'Ответь одним словом: ок', max_output_tokens: 16 });
    return !!r;
  }
  const r = await post('https://api.anthropic.com/v1/messages', claudeHeaders(settings), { model: settings.model, max_tokens: 16, messages: [{ role: 'user', content: 'Ответь одним словом: ок' }] });
  return !!r;
}

const claudeHeaders = (s) => ({ 'x-api-key': s.key.trim(), 'anthropic-version': '2023-06-01', 'anthropic-dangerous-direct-browser-access': 'true' });

async function callClaude(s, base64) {
  const msg = await post('https://api.anthropic.com/v1/messages', claudeHeaders(s), {
    model: s.model || 'claude-haiku-5-5',
    max_tokens: 1500,
    output_config: { format: { type: 'json_schema', schema: SCHEMA } },
    messages: [{ role: 'user', content: [
      { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: base64 } },
      { type: 'text', text: PROMPT },
    ] }],
  });
  if (msg.stop_reason === 'refusal') throw new AiError('refusal', 'ИИ отказался разбирать это фото. Попробуй другое или заполни вручную.');
  const text = msg.content?.find((b) => b.type === 'text')?.text;
  return parseJson(text);
}

async function callOpenAI(s, base64) {
  const r = await post('https://api.openai.com/v1/responses', { authorization: `Bearer ${s.key.trim()}` }, {
    model: s.model || 'gpt-6-astra',
    input: [{ role: 'user', content: [
      { type: 'input_text', text: PROMPT },
      { type: 'input_image', image_url: `data:image/jpeg;base64,${base64}`, detail: 'high' },
    ] }],
    text: { format: { type: 'json_schema', name: 'product', strict: true, schema: SCHEMA } },
  });
  const text = r.output_text ?? r.output?.flatMap((o) => o.content || []).find((c) => c.type === 'output_text')?.text;
  return parseJson(text);
}

async function post(url, headers, body) {
  let res;
  try {
    res = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
  } catch {
    throw new AiError('network', 'Нет связи с сервисом ИИ. Проверь интернет и попробуй ещё раз.');
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const m = data?.error?.message || res.statusText;
    if (res.status === 401) throw new AiError('auth', 'Ключ не подошёл. Проверь, что он скопирован целиком.');
    if (res.status === 402 || /credit|billing|quota/i.test(m)) throw new AiError('billing', 'На счёте ИИ закончились деньги или лимит. Пополни баланс в консоли.');
    if (res.status === 429) throw new AiError('rate', 'Слишком много запросов. Подожди минуту и попробуй снова.');
    if (res.status === 404 || /model/i.test(m)) throw new AiError('model', `Модель недоступна для этого ключа (${m}). Выбери другую в настройках.`);
    if (res.status >= 500) throw new AiError('server', 'Сервис ИИ перегружен. Попробуй через минуту.');
    throw new AiError('other', `Ошибка ИИ: ${m}`);
  }
  return data;
}

function parseJson(text) {
  if (!text) throw new AiError('empty', 'ИИ вернул пустой ответ. Попробуй другое фото.');
  try { return JSON.parse(text); } catch {}
  const m = text.match(/\{[\s\S]*\}/);
  if (m) { try { return JSON.parse(m[0]); } catch {} }
  throw new AiError('parse', 'Не получилось разобрать ответ ИИ. Попробуй ещё раз.');
}

function normalize(r) {
  const actives = (r.actives || []).filter((a) => activeIds.includes(a));
  const form = r.retinoid_form && r.retinoid_form !== 'none' && RETINOID_FORMS[r.retinoid_form] ? r.retinoid_form : null;
  if (form && !actives.includes('retinoid')) actives.unshift('retinoid');
  return {
    isSkincare: r.is_skincare !== false,
    brand: (r.brand || '').trim(),
    name: (r.name || '').trim(),
    type: PRODUCT_TYPES[r.product_type] ? r.product_type : 'other',
    actives,
    retinoidForm: actives.includes('retinoid') ? (form || 'retinol') : null,
    strength: (r.strength || '').trim(),
    time: ['morning', 'evening'].includes(r.time_of_day) ? r.time_of_day : 'any',
    composition: (r.inci_text || '').trim(),
    confidence: r.confidence || 'medium',
    note: (r.note_ru || '').trim(),
  };
}

async function thumbFromDataUrl(dataUrl, size = 160) {
  const img = await new Promise((res) => { const i = new Image(); i.onload = () => res(i); i.src = dataUrl; });
  const s = Math.min(img.width, img.height);
  const c = document.createElement('canvas'); c.width = size; c.height = size;
  c.getContext('2d').drawImage(img, (img.width - s) / 2, (img.height - s) / 2, s, s, 0, 0, size, size);
  return c.toDataURL('image/jpeg', 0.75);
}
export async function thumbFromFile(file) { const r = await resizeImage(file, 480, 0.8); return thumbFromDataUrl(r.dataUrl); }

export class AiError extends Error { constructor(code, msg) { super(msg); this.code = code; } }
