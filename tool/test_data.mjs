import { randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export function fixturePlan({ runId = randomUUID(), fixtureDate } = {}) {
  if (!uuid.test(runId ?? '')) throw new Error('A canonical lowercase test-run UUID is required.');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fixtureDate ?? '') ||
      !Number.isFinite(Date.parse(fixtureDate)) ||
      new Date(fixtureDate).toISOString().slice(0, 10) !== fixtureDate) {
    throw new Error('Use a real fixture date in YYYY-MM-DD format.');
  }
  return {
    mode: 'OFFLINE_PLAN', runId, fixtureDate,
    dataSource: 'SYNTHETIC TEST DATA - NOT A REAL USER',
    ownerEmail: `owner.${runId}@rental-test.invalid`,
    providerEmail: `provider.${runId}@rental-test.invalid`,
    planned: { accounts: 2, properties: 2, weeklySlots: 7, pendingBookings: 1 },
    deletionSupported: false,
  };
}

// Server-side administrator tool; never import it into Flutter/browser code.
// No Auth provisioning, password logging, Storage deletion or broad row sweep.
export async function manageTestData({ env, action = 'seed', runId, fixtureDate,
  ownerId, providerId, execute = false, confirmProject, fetchImpl = fetch }) {
  if (!['seed', 'inventory'].includes(action)) throw new Error('Unknown action.');
  if (!uuid.test(runId ?? '')) throw new Error('A canonical lowercase test-run UUID is required.');
  if (action === 'inventory' && execute) throw new Error('Inventory is read-only; deletion is not supported.');
  if (action === 'seed') {
    fixturePlan({ runId, fixtureDate });
    if (!uuid.test(ownerId ?? '') || !uuid.test(providerId ?? '') || ownerId === providerId) {
      throw new Error('Two distinct explicitly provisioned test Auth account IDs are required.');
    }
  }
  const ref = env.SUPABASE_PROJECT_REF;
  const base = env.SUPABASE_URL;
  if (env.APP_ENV !== 'staging' || !/^[a-z]{20}$/.test(ref ?? '') ||
      base !== `https://${ref}.supabase.co`) throw new Error('Only an explicitly configured staging project is allowed.');
  if (execute && confirmProject !== ref) throw new Error('Creation requires --confirm-project matching the configured staging Project ID.');
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  let role;
  try { role = JSON.parse(Buffer.from(key.split('.')[1], 'base64url')).role; } catch {}
  if (role !== 'service_role' && !/^sb_secret_[A-Za-z0-9_-]+$/.test(key ?? '')) {
    throw new Error('A server-only administrator credential is required, never a publishable/anon key.');
  }
  const rpc = async (name, body = {}) => {
    const headers = { apikey: key, 'Content-Type': 'application/json' };
    if (role === 'service_role') headers.Authorization = `Bearer ${key}`;
    let response;
    try {
      response = await fetchImpl(`${base}/rest/v1/rpc/${name}`, {
        method: 'POST', headers, body: JSON.stringify(body), signal: AbortSignal.timeout(15000),
        redirect: 'error',
      });
    } catch {
      // A lost seed reply is uncertain, not proof of rollback. Same run IDs are
      // retry-safe; never retry by inventing another batch or new Auth accounts.
      throw new Error('Request interrupted. Do not assume rollback; retry the same run/parameters.');
    }
    if (!response.ok) throw new Error(`Test-data request failed (${response.status}). No credential or response body is logged.`);
    try { return await response.json(); } catch { throw new Error('Invalid reply; inspect/retry the same run, do not create another.'); }
  };
  const marker = await rpc('get_app_environment');
  if (marker?.environment !== 'staging' || marker?.project_ref !== ref) {
    throw new Error('Server environment mismatch. No fixture access allowed.');
  }
  const parameters = { p_project_ref: ref, p_run_id: runId };
  if (action === 'inventory') {
    const result = await rpc('inspect_test_run', parameters);
    if (result?.run_id !== runId || result?.deletion_supported !== false) throw new Error('Unexpected inventory contract.');
    return { mode: 'READ_ONLY_INVENTORY', ...result };
  }
  const result = await rpc(execute ? 'seed_test_fixture' : 'preview_test_fixture', {
    ...parameters, p_owner_id: ownerId, p_provider_id: providerId, p_fixture_date: fixtureDate,
  });
  if (result?.run_id !== runId || typeof result.already_seeded !== 'boolean') {
    throw new Error('Unexpected seed reply; inspect/retry the same run.');
  }
  return { mode: execute ? 'SEED' : 'DRY_RUN', ...result };
}

export function parseArguments(args) {
  const [action = 'plan', ...rest] = args;
  if (!['plan', 'seed', 'inventory'].includes(action)) throw new Error('Use plan, seed or inventory. No delete action exists.');
  const allowed = new Set(action === 'inventory' ? ['run'] : action === 'plan' ?
    ['run', 'date'] : ['run', 'date', 'owner', 'provider', 'execute', 'confirm-project']);
  const values = {};
  for (let i = 0; i < rest.length; i++) {
    const name = rest[i].startsWith('--') ? rest[i].slice(2) : '';
    if (!allowed.has(name) || Object.hasOwn(values, name)) throw new Error('Unknown or duplicate argument.');
    if (name === 'execute') values[name] = true;
    else {
      if (!rest[i + 1] || rest[i + 1].startsWith('--')) throw new Error('Missing argument value.');
      values[name] = rest[++i];
    }
  }
  return { action, runId: values.run, fixtureDate: values.date, ownerId: values.owner,
    providerId: values.provider, execute: values.execute === true, confirmProject: values['confirm-project'] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const options = parseArguments(process.argv.slice(2));
    const result = options.action === 'plan' ? fixturePlan(options) :
      await manageTestData({ ...options, env: process.env });
    console.log(JSON.stringify(result, null, 2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
