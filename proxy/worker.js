// Сервер-посредник «Ритма кожи». Приложение шлёт фото упаковки с инвайт-кодом,
// сервер добавляет ключ владельца и пересылает в OpenAI или Claude. Ключ в телефоны не попадает,
// а запрос к ИИ идёт с сервера — это работает и там, где ИИ напрямую недоступен.
//
// Секреты (wrangler secret put …):
//   OPENAI_API_KEY     — ключ OpenAI (для /openai)
//   ANTHROPIC_API_KEY  — ключ Anthropic (для /anthropic), необязательно
//   INVITES            — инвайт-коды через запятую: "vika,husband"
// Переменные: DAILY_LIMIT (по умолчанию 60). KV-привязка USAGE (необязательно) — для лимита.

const OPENAI_MODELS = ['gpt-4.1-mini', 'gpt-5-mini', 'gpt-5-nano', 'gpt-5.4-mini'];
const CLAUDE_MODELS = ['claude-haiku-5-5', 'claude-sonnet-5-5'];

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors() });
    const url = new URL(request.url);
    if (request.method === 'GET') return json({ ok: true, service: 'ritm-kozhi-proxy', openai: !!env.OPENAI_API_KEY, anthropic: !!env.ANTHROPIC_API_KEY });
    if (request.method !== 'POST') return json({ error: { message: 'POST only' } }, 405);

    const code = (request.headers.get('x-invite') || '').trim().toLowerCase();
    const invites = (env.INVITES || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
    if (!code || !invites.includes(code)) return json({ error: { message: 'Неверный инвайт-код' } }, 401);

    if (env.USAGE) {
      const key = `${code}:${new Date().toISOString().slice(0, 10)}`;
      const used = Number((await env.USAGE.get(key)) || 0);
      const limit = Number(env.DAILY_LIMIT || 60);
      if (used >= limit) return json({ error: { message: `Лимит ${limit} запросов в день` } }, 429);
      await env.USAGE.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
    }

    let body;
    try { body = await request.json(); } catch { return json({ error: { message: 'Bad JSON' } }, 400); }

    if (url.pathname.startsWith('/openai')) {
      if (!env.OPENAI_API_KEY) return json({ error: { message: 'На сервере нет ключа OpenAI' } }, 500);
      if (!OPENAI_MODELS.includes(body.model)) body.model = OPENAI_MODELS[0];
      delete body.tools; // только распознавание
      const upstream = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${env.OPENAI_API_KEY}` },
        body: JSON.stringify(body),
      });
      return new Response(upstream.body, { status: upstream.status, headers: { 'content-type': 'application/json', ...cors() } });
    }

    if (!env.ANTHROPIC_API_KEY) return json({ error: { message: 'На сервере нет ключа Anthropic' } }, 500);
    if (!CLAUDE_MODELS.includes(body.model)) body.model = CLAUDE_MODELS[0];
    body.max_tokens = Math.min(Number(body.max_tokens) || 1500, 2000);
    delete body.tools; delete body.system;
    const upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify(body),
    });
    return new Response(upstream.body, { status: upstream.status, headers: { 'content-type': 'application/json', ...cors() } });
  },
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json', ...cors() } });
}
function cors() {
  return { 'access-control-allow-origin': '*', 'access-control-allow-headers': 'content-type, x-invite, anthropic-version', 'access-control-allow-methods': 'GET, POST, OPTIONS' };
}
