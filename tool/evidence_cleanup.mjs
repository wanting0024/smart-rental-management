import { pathToFileURL } from 'node:url';

// Administrator/server-only tool. Default is read-only. No secrets are loaded
// from committed files or printed, and no bucket-wide list/delete is performed.
export async function runCleanup({ env, execute = false, fetchImpl = fetch }) {
  const ref = env.SUPABASE_PROJECT_REF;
  const base = env.SUPABASE_URL?.replace(/\/$/, '');
  const environment = env.APP_ENV;
  if (!/^[a-z]{20}$/.test(ref ?? '') || base !== `https://${ref}.supabase.co` ||
      !['staging', 'production'].includes(environment)) throw new Error('Invalid environment configuration.');
  if (execute && environment === 'production' && env.ALLOW_PRODUCTION_CLEANUP !== 'true') {
    throw new Error('Production deletion requires explicit administrator opt-in.');
  }
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  let role;
  try { role = JSON.parse(Buffer.from(key.split('.')[1], 'base64url')).role; } catch {}
  if (role !== 'service_role') throw new Error('A server-side service-role credential is required, never a client key.');
  const request = async (path, body, method = 'POST') => {
    const response = await fetchImpl(`${base}${path}`, {
      method, headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`Maintenance request failed (${response.status}). No credential or response body is logged.`);
    return response.json();
  };
  const rpc = (name, body = {}) => request(`/rest/v1/rpc/${name}`, body);
  const marker = await rpc('get_app_environment');
  if (marker?.environment !== environment || marker?.project_ref !== ref) {
    throw new Error('Server environment mismatch. No cleanup permitted.');
  }
  const rows = await rpc(execute ? 'claim_evidence_cleanup_batch' : 'list_evidence_cleanup_batch');
  if (!Array.isArray(rows) || rows.length > 20) throw new Error('Invalid cleanup batch.');
  // Validate the entire batch before any Storage deletion, including known
  // legacy filenames. Never accept prefixes, traversal, URLs or arbitrary paths.
  for (const row of rows) {
    if (!/^[a-f0-9-]{36}$/.test(row.booking_id ?? '') ||
        typeof row.object_path !== 'string' ||
        !row.object_path.startsWith(`${row.booking_id}/`) ||
        !/^[a-f0-9-]{36}\/[A-Za-z0-9_-]+\.(jpg|jpeg|png)$/.test(row.object_path)) {
      throw new Error('Unsafe cleanup path; administrator review required.');
    }
  }
  if (!execute) return { mode: 'DRY_RUN', candidates: rows.length, deleted: 0 };
  let deleted = 0;
  for (const row of rows) {
    await request('/storage/v1/object/cleaning-evidence', { prefixes: [row.object_path] }, 'DELETE');
    const confirmed = await rpc('finish_evidence_cleanup_batch', {
      p_booking_id: row.booking_id, p_path: row.object_path,
    });
    if (confirmed !== true) throw new Error('Object removal was not confirmed; its tombstone is retained for retry.');
    deleted++;
  }
  return { mode: 'EXECUTE', candidates: rows.length, deleted, batchFull: rows.length === 20 };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--execute')) {
    console.error('Usage: node tool/evidence_cleanup.mjs [--execute]');
    process.exitCode = 1;
  } else {
    try { console.log(JSON.stringify(await runCleanup({ env: process.env, execute: args.includes('--execute') }))); }
    catch (error) { console.error(error.message); process.exitCode = 1; }
  }
}
