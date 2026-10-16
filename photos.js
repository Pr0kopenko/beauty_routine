// Фото лица — в IndexedDB этого устройства. Никуда не отправляются.

const DB = 'ritm-kozhi-photos';
let dbp;
function db() {
  if (!dbp) dbp = new Promise((res, rej) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => r.result.createObjectStore('photos', { keyPath: 'id' });
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  });
  return dbp;
}
async function tx(mode, fn) {
  const d = await db();
  return new Promise((res, rej) => {
    const t = d.transaction('photos', mode);
    const out = fn(t.objectStore('photos'));
    t.oncomplete = () => res(out?.result ?? out);
    t.onerror = () => rej(t.error);
  });
}
export const putPhoto = (rec) => tx('readwrite', (s) => s.put(rec));
export const deletePhoto = (id) => tx('readwrite', (s) => s.delete(id));
export async function getPhoto(id) { const d = await db(); return new Promise((res, rej) => { const r = d.transaction('photos').objectStore('photos').get(id); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); }
export async function allPhotos() { const d = await db(); return new Promise((res, rej) => { const r = d.transaction('photos').objectStore('photos').getAll(); r.onsuccess = () => res(r.result || []); r.onerror = () => rej(r.error); }); }

const urls = new Map();
export async function photoUrl(id) {
  if (urls.has(id)) return urls.get(id);
  const rec = await getPhoto(id);
  if (!rec) return null;
  const u = URL.createObjectURL(rec.blob); urls.set(id, u); return u;
}

export async function photosToJson() {
  const list = await allPhotos();
  return Promise.all(list.map(async (p) => ({ id: p.id, day: p.day, at: p.at, data: await blobToDataUrl(p.blob) })));
}
export async function photosFromJson(arr) {
  for (const p of arr || []) { const blob = await (await fetch(p.data)).blob(); await putPhoto({ id: p.id, day: p.day, at: p.at, blob }); }
}
const blobToDataUrl = (b) => new Promise((res) => { const r = new FileReader(); r.onload = () => res(r.result); r.readAsDataURL(b); });
