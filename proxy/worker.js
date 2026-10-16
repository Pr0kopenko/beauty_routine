// Сервер-посредник для друзей: приложение шлёт фото упаковки с инвайт-кодом,
// сервер добавляет ваш ключ Anthropic и пересылает в Claude. Ключ у друзей не появляется.
//
// Переменные (Cloudflare → Workers → Settings → Variables):
//   ANTHROPIC_API_KEY — секрет, ваш ключ
//   INVITES           — коды через запятую: "masha,olya,lena"
//   DAILY_LIMIT       — запросов на код в сутки (по умолчанию 40)
// KV-привязка (необязательно, для лимитов): USAGE

const ALLOWED_MODELS = ['claude-haiku-5-5', 'claude-sonnet-5-5'];

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors() });
    if (request.method !== 'POST') return json({ error: { message: 'POST only' } }, 405);

    const code = (request.headers.get('x-invite') || '').trim().toLowerCase();
    const invites = (env.INVITES || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
    if (!code || !invites.includes(code)) return json({ error: { message: 'Неверный инвайт-код' } }, 401);

    if (env.USAGE) {
      const key = `${code}:${new Date().toISOString().slice(0, 10)}`;
      const used = Number((await env.USAGE.get(key)) || 0);
      const limit = Number(env.DAILY_LIMIT || 40);
      if (used >= limit) return json({ error: { message: `Лимит ${limit} распознаваний в день` } }, 429);
      await env.USAGE.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
    }

    let body;
    try { body = await request.json(); } catch { return json({ error: { message: 'Bad JSON' } }, 400); }
    if (!ALLOWED_MODELS.includes(body.model)) body.model = ALLOWED_MODELS[0];
    body.max_tokens = Math.min(Number(body.max_tokens) || 1500, 2000);
    delete body.tools; delete body.system; // только распознавание, без произвольных инструментов

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
  return { 'access-control-allow-origin': '*', 'access-control-allow-headers': 'content-type, x-invite, anthropic-version', 'access-control-allow-methods': 'POST, OPTIONS' };
}
