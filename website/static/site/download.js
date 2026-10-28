export const MISSING_APK = 'Ilova fayli hozircha joylanmagan. Iltimos, keyinroq qayta urinib ko‘ring.';
export function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return '';
  return bytes < 1024 * 1024 ? `${Math.ceil(bytes / 1024)} KB` : `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
export async function probeApk(url, fetcher = globalThis.fetch, timeoutMs = 12000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetcher(url, { method: 'HEAD', cache: 'no-cache', signal: controller.signal });
    if (response.status === 404) return { available: false, message: MISSING_APK };
    if (!response.ok) return { available: false, message: 'Yuklab olish hozir ishlamayapti. Keyinroq qayta urinib ko‘ring.' };
    const type = (response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    const allowed = ['application/vnd.android.package-archive', 'application/octet-stream', 'application/zip', 'binary/octet-stream'];
    if (!allowed.includes(type)) return { available: false, message: MISSING_APK };
    const rawSize = Number(response.headers.get('content-length'));
    return { available: true, size: Number.isFinite(rawSize) && rawSize > 0 ? rawSize : null };
  } catch {
    return { available: false, message: 'Ulanishni tekshirib, qayta urinib ko‘ring. Faylni yuklab olish boshlanmadi.' };
  } finally { clearTimeout(timer); }
}
