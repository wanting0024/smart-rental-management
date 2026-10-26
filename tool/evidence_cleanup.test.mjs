import test from 'node:test';
import assert from 'node:assert/strict';
import { runCleanup } from './evidence_cleanup.mjs';

const ref = 'aaaaaaaaaaaaaaaaaaaa';
const env = { APP_ENV: 'staging', SUPABASE_PROJECT_REF: ref, SUPABASE_URL: `https://${ref}.supabase.co`,
  SUPABASE_SERVICE_ROLE_KEY: `test.${Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url')}.not-a-real-key` };
const id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const row = { booking_id: id, object_path: `${id}/before_test.png` };
function mock({ marker = { environment:'staging',project_ref:ref }, rows = [row], confirmed = true, failDelete = false } = {}) {
  const calls = [];
  return { calls, fetchImpl: async (url, options) => {
    const path = new URL(url).pathname;
    calls.push({ path, method:options.method, body:JSON.parse(options.body) });
    if (path.endsWith('get_app_environment')) return { ok:true,json:async()=>marker };
    if (path.includes('/storage/')) return { ok:!failDelete,status:503,json:async()=>[] };
    if (path.includes('finish_')) return { ok:true,json:async()=>confirmed };
    return { ok:true,json:async()=>rows };
  } };
}
test('dry-run only reads a verified marker and bounded candidates',async()=>{
  const m=mock(); const result=await runCleanup({env,...m});
  assert.deepEqual(result,{mode:'DRY_RUN',candidates:1,deleted:0});
  assert.equal(m.calls.length,2); assert.ok(m.calls[1].path.endsWith('list_evidence_cleanup_batch'));
});
test('execute uses Storage API and confirms disappearance',async()=>{
  const m=mock(); const result=await runCleanup({env,execute:true,...m});
  assert.equal(result.deleted,1); assert.equal(m.calls[2].method,'DELETE');
  assert.deepEqual(m.calls[2].body,{prefixes:[row.object_path]});
  assert.ok(m.calls[3].path.endsWith('finish_evidence_cleanup_batch'));
});
test('environment mismatch and production without opt-in cannot delete',async()=>{
  const m=mock({marker:{environment:'production',project_ref:ref}});
  await assert.rejects(runCleanup({env,execute:true,...m}),/mismatch/); assert.equal(m.calls.length,1);
  const m2=mock(); await assert.rejects(runCleanup({env:{...env,APP_ENV:'production'},execute:true,...m2}),/opt-in/);
  assert.equal(m2.calls.length,0);
});
test('unsafe path stops deletion; failed deletion never marks complete',async()=>{
  const m=mock({rows:[{...row,object_path:`${id}/../other.png`}]});
  await assert.rejects(runCleanup({env,execute:true,...m}),/Unsafe/); assert.equal(m.calls.length,2);
  const failed=mock({failDelete:true}); await assert.rejects(runCleanup({env,execute:true,...failed}),/503/);
  assert.equal(failed.calls.length,3);
});
test('silent Storage denial remains an unconfirmed tombstone',async()=>{
  const m=mock({confirmed:false}); await assert.rejects(runCleanup({env,execute:true,...m}),/not confirmed/);
});
