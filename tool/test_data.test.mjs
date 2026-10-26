import test from 'node:test';
import assert from 'node:assert/strict';
import { fixturePlan, manageTestData, parseArguments } from './test_data.mjs';

const ref = 'aaaaaaaaaaaaaaaaaaaa';
const runId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ownerId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const providerId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const env = { APP_ENV: 'staging', SUPABASE_PROJECT_REF: ref, SUPABASE_URL: `https://${ref}.supabase.co`,
  SUPABASE_SERVICE_ROLE_KEY: `test.${Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url')}.not-a-real-key` };
const options = { env, runId, ownerId, providerId, fixtureDate: '2030-01-08' };
function mock({ marker = { environment: 'staging', project_ref: ref }, reply = {
  run_id: runId, already_seeded: false, deletion_supported: false,
}, fail = false } = {}) {
  const calls = [];
  return { calls, fetchImpl: async (url, init) => {
    const path = new URL(url).pathname;
    calls.push({ path, ...init, body: JSON.parse(init.body) });
    return { ok: !fail, status: fail ? 403 : 200, json: async () =>
      path.endsWith('get_app_environment') ? marker : reply };
  } };
}

test('offline fixture plans are repeatable, synthetic, and contain no credential', () => {
  const a = fixturePlan({ runId, fixtureDate: options.fixtureDate });
  assert.deepEqual(a, fixturePlan({ runId, fixtureDate: options.fixtureDate }));
  assert.match(a.ownerEmail, /@rental-test\.invalid$/);
  assert.match(a.dataSource, /NOT A REAL USER/);
  assert.equal(a.deletionSupported, false);
  assert.ok(!JSON.stringify(a).includes('password'));
  assert.notEqual(fixturePlan({ fixtureDate: options.fixtureDate }).runId, runId);
});
test('invalid IDs and normalized impossible dates are rejected before network access', async () => {
  for (const fixtureDate of ['2030-02-30', '2030-13-01', '1/8/2030']) {
    assert.throws(() => fixturePlan({ runId, fixtureDate }), /real fixture date/);
  }
  const m = mock();
  await assert.rejects(manageTestData({ ...options, ...m, ownerId: providerId }), /distinct/);
  await assert.rejects(manageTestData({ ...options, ...m, runId: '../unsafe' }), /UUID/);
  assert.equal(m.calls.length, 0);
});
test('seed defaults to read-only preview, with exact account IDs and date', async () => {
  const m = mock(); const result = await manageTestData({ ...options, ...m });
  assert.equal(result.mode, 'DRY_RUN'); assert.equal(m.calls.length, 2);
  assert.ok(m.calls[1].path.endsWith('preview_test_fixture'));
  assert.deepEqual(m.calls[1].body, { p_project_ref: ref, p_run_id: runId,
    p_owner_id: ownerId, p_provider_id: providerId, p_fixture_date: options.fixtureDate });
  assert.ok(m.calls.every(c => !c.path.includes('/auth/') && !c.path.includes('/storage/')));
});
test('execute requires explicit project confirmation, then uses atomic seed RPC only', async () => {
  const m = mock();
  await assert.rejects(manageTestData({ ...options, ...m, execute: true }), /confirm-project/);
  assert.equal(m.calls.length, 0);
  const result = await manageTestData({ ...options, ...m, execute: true, confirmProject: ref });
  assert.equal(result.mode, 'SEED'); assert.ok(m.calls[1].path.endsWith('seed_test_fixture'));
});
test('production is unconditionally rejected, including correctly confirmed Project ID', async () => {
  const m = mock();
  for (const APP_ENV of ['production', 'local', 'unassigned']) {
    await assert.rejects(manageTestData({ ...options, ...m, env: { ...env, APP_ENV },
      execute: true, confirmProject: ref }), /staging/);
  }
  assert.equal(m.calls.length, 0);
});
test('hosted marker mismatch cannot reach fixture RPC', async () => {
  for (const marker of [{ environment: 'production', project_ref: ref },
    { environment: 'staging', project_ref: 'bbbbbbbbbbbbbbbbbbbb' }, null]) {
    const m = mock({ marker });
    await assert.rejects(manageTestData({ ...options, ...m }), /mismatch/);
    assert.equal(m.calls.length, 1);
  }
});
test('client keys and redirected/custom project URLs are rejected', async () => {
  const m = mock();
  for (const overrides of [{ SUPABASE_SERVICE_ROLE_KEY: 'sb_publishable_test' },
    { SUPABASE_URL: `${env.SUPABASE_URL}/evil` }, { SUPABASE_URL: 'http://localhost' }]) {
    await assert.rejects(manageTestData({ ...options, ...m, env: { ...env, ...overrides } }));
  }
  assert.equal(m.calls.length, 0);
});
test('new server secret keys are apikey-only; legacy service JWT also uses bearer', async () => {
  const m = mock(); await manageTestData({ ...options, ...m });
  assert.equal(m.calls[0].headers.Authorization, `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`);
  const n = mock(); await manageTestData({ ...options, ...n,
    env: { ...env, SUPABASE_SERVICE_ROLE_KEY: ['sb', 'secret', 'not-a-real-secret'].join('_') } });
  assert.equal(n.calls[0].headers.Authorization, undefined);
  assert.equal(n.calls[0].redirect, 'error');
});
test('inventory never mutates, and unsafe delete/execute arguments are not accepted', async () => {
  const m = mock(); const result = await manageTestData({ env, runId, action: 'inventory', ...m });
  assert.equal(result.mode, 'READ_ONLY_INVENTORY');
  assert.ok(m.calls[1].path.endsWith('inspect_test_run'));
  await assert.rejects(manageTestData({ env, runId, action: 'inventory', execute: true, ...m }), /read-only/);
  for (const args of [['delete'], ['inventory', '--run', runId, '--execute'],
    ['seed', '--delete'], ['seed', '--run'], ['seed', '--run', runId, '--run', runId],
    ['plan', '--owner', ownerId]]) assert.throws(() => parseArguments(args));
});
test('CLI parser preserves explicit values without silently enabling writes', () => {
  assert.equal(parseArguments(['seed', '--run', runId, '--date', '2030-01-08', '--owner', ownerId,
    '--provider', providerId]).execute, false);
  const a = parseArguments(['seed', '--execute', '--confirm-project', ref]);
  assert.equal(a.execute, true); assert.equal(a.confirmProject, ref);
});
test('HTTP error bodies and transport errors do not leak secrets or user data', async () => {
  const m = mock({ fail: true });
  await assert.rejects(manageTestData({ ...options, ...m }), error =>
    error.message.includes('403') && !error.message.includes(env.SUPABASE_SERVICE_ROLE_KEY));
  await assert.rejects(manageTestData({ ...options, fetchImpl: async () => {
    throw new Error(`transport leaked ${env.SUPABASE_SERVICE_ROLE_KEY}`);
  } }), /Do not assume rollback/);
});
test('unexpected or lost replies do not claim creation succeeded', async () => {
  const m = mock({ reply: { run_id: ownerId, already_seeded: false } });
  await assert.rejects(manageTestData({ ...options, ...m }), /Unexpected seed reply/);
  const n = mock({ reply: { run_id: runId, deletion_supported: true } });
  await assert.rejects(manageTestData({ ...options, ...n, action: 'inventory' }), /contract/);
});
