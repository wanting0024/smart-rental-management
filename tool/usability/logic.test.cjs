const test = require('node:test');
const assert = require('node:assert/strict');
const kit = require('./logic.js');
const base = () => ({
  task_id: 'O02', role: 'Owner', participant_code: 'P01',
  record_type: 'OBSERVED_USABILITY_SESSION', mode: 'CONNECTED_SESSION',
  environment_verified: true, first_booking: true, prerequisites_ready: true,
  outcome: 'INDEPENDENT', guidance_count: 0, server_confirmed: true,
  elapsed_seconds: 300, device: 'Technical test fixture', build: 'unit-test',
  notes: '', ease_score: '',
});
test('only observed verified first attempts can satisfy the five-minute target', () => {
  assert.equal(kit.evaluateNfr(base()), 'PASS');
  for (const patch of [{ record_type: 'FACILITATOR_DRY_RUN' },
    { mode: 'LOCAL_UI_REVIEW' }, { first_booking: false },
    { environment_verified: false }, { prerequisites_ready: false },
    { outcome: 'BLOCKED' }]) {
    assert.equal(kit.evaluateNfr({ ...base(), ...patch }), 'NOT_EVALUATED');
  }
  assert.equal(kit.evaluateNfr(base(), [base()]), 'NOT_EVALUATED');
  assert.equal(kit.evaluateNfr({ ...base(), participant_code: 'P02' }, [base()]), 'PASS');
});
test('the 300-second boundary, guidance, failed outcomes and missing confirmation stay distinct', () => {
  assert.equal(kit.evaluateNfr({ ...base(), elapsed_seconds: 300.001 }), 'FAIL');
  assert.equal(kit.evaluateNfr({ ...base(), guidance_count: 1 }), 'FAIL');
  assert.equal(kit.evaluateNfr({ ...base(), outcome: 'ASSISTED' }), 'FAIL');
  assert.equal(kit.evaluateNfr({ ...base(), outcome: 'FAILED' }), 'FAIL');
  assert.equal(kit.evaluateNfr({ ...base(), server_confirmed: false }), 'UNVERIFIED');
});
test('record validation rejects inconsistent outcomes and missing anonymous identifiers', () => {
  assert.deepEqual(kit.validateRecord(base()), []);
  assert.ok(kit.validateRecord({ ...base(), participant_code: 'a real email' }).length);
  assert.ok(kit.validateRecord({ ...base(), guidance_count: 1 }).length);
  assert.ok(kit.validateRecord({ ...base(), outcome: 'ASSISTED', guidance_count: 0 }).length);
  assert.ok(kit.validateRecord({ ...base(), outcome: 'BLOCKED' }).length);
  assert.deepEqual(kit.validateRecord({ ...base(), outcome: 'BLOCKED',
    environment_verified: false, notes: 'Technical fixture unavailable' }), []);
  assert.ok(kit.validateRecord({ ...base(), elapsed_seconds: NaN }).length);
});
test('CSV preserves rows and quotes while neutralising formula prefixes', () => {
  const csv = kit.toCsv([{ ...base(), notes: '=1+1', evidence_reference: 'a,"b"\nline' }]);
  assert.ok(csv.includes('"\'=1+1"'));
  assert.ok(csv.includes('"a,""b""\nline"'));
  assert.equal(kit.toCsv([]).split('\r\n').length, 1);
});
test('all planned tasks are uniquely identified and limited to Owner / Provider', () => {
  assert.equal(kit.tasks.length, 12);
  assert.equal(new Set(kit.tasks.map(t => t.id)).size, 12);
  assert.ok(kit.tasks.every(t => ['Owner', 'Provider'].includes(t.role)));
});
