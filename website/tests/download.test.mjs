import test from 'node:test';
import assert from 'node:assert/strict';
import { probeApk, formatBytes, MISSING_APK } from '../static/site/download.js';
const response = (status, type, size) => new Response(null, { status, headers: { 'content-type': type, ...(size ? { 'content-length': String(size) } : {}) } });
test('missing APK gives the exact user message', async () => {
  const result = await probeApk('/downloads/dokon-boshqaruv.apk', async () => response(404, 'application/json'));
  assert.equal(result.available, false); assert.equal(result.message, MISSING_APK);
});
test('available Android APK uses HEAD and real content length', async () => {
  const result = await probeApk('/downloads/dokon-boshqaruv.apk', async (url, options) => {
    assert.equal(url, '/downloads/dokon-boshqaruv.apk'); assert.equal(options.method, 'HEAD');
    return response(200, 'application/vnd.android.package-archive', 1048576);
  });
  assert.deepEqual(result, { available: true, size: 1048576 });
});
test('HTML fallback is never downloaded as an APK', async () => {
  assert.equal((await probeApk('/file.apk', async () => response(200, 'text/html'))).available, false);
});
test('unknown size remains unknown', async () => {
  assert.equal((await probeApk('/file.apk', async () => response(200, 'application/octet-stream'))).size, null);
});
test('server error is visible', async () => {
  const result = await probeApk('/file.apk', async () => response(503, 'text/html'));
  assert.equal(result.available, false); assert.ok(result.message.length > 10);
});
test('network error is visible', async () => {
  const result = await probeApk('/file.apk', async () => { throw new TypeError('Offline'); });
  assert.equal(result.available, false); assert.match(result.message, /Ulanishni/);
});
test('request timeout is finite', async () => {
  const result = await probeApk('/file.apk', (_, { signal }) => new Promise((_, reject) => signal.addEventListener('abort', () => reject(new Error('timeout')))), 5);
  assert.equal(result.available, false);
});
test('file-size formatting never invents a size', () => {
  assert.equal(formatBytes(null), ''); assert.equal(formatBytes(NaN), ''); assert.equal(formatBytes(0), '');
  assert.equal(formatBytes(1048576), '1.0 MB'); assert.equal(formatBytes(1024), '1 KB');
});
