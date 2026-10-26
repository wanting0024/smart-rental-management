(function () {
  'use strict';
  const kit = globalThis.UsabilityKit;
  const $ = id => document.getElementById(id);
  const storageKey = 'smart-rental-usability-v1';
  const metaIds = ['role', 'mode', 'participant', 'device', 'build', 'network',
    'observed', 'verified', 'first-booking', 'task', 'ready'];
  const fieldIds = [...metaIds, 'outcome', 'guidance', 'ease', 'evidence', 'confirmed', 'notes'];
  let records = [], startedAt = null, endedAt = null, lockedMeta = null;
  let sessionId = makeId('session');

  function makeId(prefix) {
    return prefix + '-' + (globalThis.crypto?.randomUUID?.() ||
      Date.now().toString(36) + '-' + Math.random().toString(36).slice(2));
  }
  function message(text, kind = '') {
    $('message').textContent = text;
    $('message').className = 'message ' + kind;
  }
  function values() {
    return Object.fromEntries(fieldIds.map(id => [id,
      $(id).type === 'checkbox' ? $(id).checked : $(id).value]));
  }
  function persist() {
    try {
      localStorage.setItem(storageKey, JSON.stringify({ records,
        draft: { fields: values(), startedAt, endedAt, lockedMeta, sessionId } }));
    } catch (_) {
      message('Browser storage is unavailable. Keep this page open and export your records before leaving.', 'error');
    }
  }
  function currentTask() { return kit.tasks.find(t => t.id === $('task').value); }
  function updateTask() {
    const task = currentTask();
    if (!task) return;
    $('task-name').textContent = task.title;
    $('prompt').textContent = task.prompt;
    $('setup').textContent = task.setup;
    $('check').textContent = task.check;
    $('requirement').textContent = task.id + ' / ' + task.requirements;
    $('confirmed').closest('label').hidden = task.id !== 'O02';
    $('first-booking').closest('label').hidden = task.role !== 'Owner';
    $('mode-note').textContent = $('mode').value === 'CONNECTED_SESSION'
      ? 'Record actual separate-account behaviour. Verify the environment; this recorder cannot verify Supabase for you.'
      : 'Local reviews cannot establish the five-minute booking requirement or cross-account persistence.';
  }
  function updateRole(keepTask) {
    const previous = keepTask || $('task').value;
    $('task').replaceChildren(...kit.tasks.filter(t => t.role === $('role').value)
      .map(t => { const option = document.createElement('option');
        option.value = t.id; option.textContent = t.id + ' - ' + t.title; return option; }));
    if ([...$('task').options].some(o => o.value === previous)) $('task').value = previous;
    updateTask();
  }
  function updateTimer() {
    const seconds = startedAt == null ? 0 : Math.max(0,
      Math.floor(((endedAt ?? Date.now()) - startedAt) / 1000));
    $('timer').textContent = String(Math.floor(seconds / 60)).padStart(2, '0') + ':' +
      String(seconds % 60).padStart(2, '0');
    $('start').disabled = startedAt != null;
    $('stop').disabled = startedAt == null || endedAt != null;
    $('save').disabled = startedAt == null || endedAt == null;
    document.body.classList.toggle('running', startedAt != null && endedAt == null);
    for (const id of metaIds) $(id).disabled = startedAt != null;
  }
  function renderRecords() {
    $('records').replaceChildren();
    if (!records.length) {
      const row = document.createElement('tr'), cell = document.createElement('td');
      cell.colSpan = 5; cell.textContent = 'No saved attempts. Start with a facilitator dry run or a real observed session.';
      row.append(cell); $('records').append(row);
    }
    for (const record of [...records].reverse()) {
      const row = document.createElement('tr');
      for (const value of [record.record_type === 'FACILITATOR_DRY_RUN' ? 'Dry run' : record.participant_code,
        record.task_id, record.elapsed_seconds + ' s', record.outcome, record.nfr3_2_result]) {
        const cell = document.createElement('td'); cell.textContent = value; row.append(cell);
      }
      $('records').append(row);
    }
    $('count').textContent = records.length + ' saved attempt' + (records.length === 1 ? '' : 's');
    $('csv').disabled = $('json').disabled = records.length === 0;
  }
  function makeRecord() {
    const v = values(), m = lockedMeta || v, task = kit.tasks.find(t => t.id === m.task);
    const record = {
      record_id: makeId('attempt'), session_id: sessionId,
      participant_code: m.observed ? m.participant.trim().toUpperCase() : '',
      record_type: m.observed ? 'OBSERVED_USABILITY_SESSION' : 'FACILITATOR_DRY_RUN',
      role: m.role, mode: m.mode, environment_verified: m.verified,
      device: m.device.trim(), build: m.build.trim(), network: m.network.trim(),
      first_booking: m['first-booking'], task_id: m.task,
      requirements: task?.requirements || '', prerequisites_ready: m.ready,
      started_at: new Date(startedAt).toISOString(), ended_at: new Date(endedAt).toISOString(),
      elapsed_seconds: Number(((endedAt - startedAt) / 1000).toFixed(3)),
      outcome: v.outcome, guidance_count: Number(v.guidance),
      server_confirmed: m.task === 'O02' && v.confirmed,
      ease_score: v.ease === '' ? '' : Number(v.ease),
      notes: v.notes.trim(), evidence_reference: v.evidence.trim(),
    };
    record.nfr3_2_result = kit.evaluateNfr(record, records);
    return record;
  }
  function resetDraft() {
    startedAt = endedAt = lockedMeta = null;
    for (const id of ['outcome', 'ease', 'evidence', 'notes']) $(id).value = '';
    $('guidance').value = '0'; $('confirmed').checked = false;
    $('moderator-details').open = false;
    updateTimer(); persist();
  }
  $('role').addEventListener('change', () => { sessionId = makeId('session'); updateRole(); persist(); });
  $('participant').addEventListener('change', () => { sessionId = makeId('session'); });
  $('task').addEventListener('change', () => { updateTask(); $('moderator-details').open = false; persist(); });
  $('mode').addEventListener('change', updateTask);
  for (const id of fieldIds) $(id).addEventListener('input', persist);
  $('start').addEventListener('click', () => {
    if (!$('device').value.trim() || !$('build').value.trim()) {
      message('Enter a device and build identifier before starting.', 'error'); return;
    }
    if ($('observed').checked && !/^P\d{2,4}$/i.test($('participant').value.trim())) {
      message('Use an anonymous participant code such as P01.', 'error'); return;
    }
    startedAt = Date.now(); endedAt = null; lockedMeta = values();
    $('moderator-details').open = false;
    message('Timer running. Observe the task and record every external hint.');
    updateTimer(); persist();
  });
  $('stop').addEventListener('click', () => {
    endedAt = Date.now(); updateTimer(); persist();
    message('Timer stopped. Record the outcome and any guidance, then save the attempt.');
  });
  $('save').addEventListener('click', () => {
    if (startedAt == null || endedAt == null) return;
    const record = makeRecord();
    const errors = kit.validateRecord(record);
    if (!record.prerequisites_ready && record.outcome !== 'BLOCKED') errors.push('Task prerequisites were not ready. Record Blocked or reset and prepare a new attempt.');
    if (errors.length) { message(errors.join('\n'), 'error'); return; }
    records.push(record); resetDraft(); renderRecords(); persist();
    if (record.task_id === 'O02') { $('first-booking').checked = false; persist(); }
    message('Saved ' + record.task_id + ' as ' + record.record_type + '. NFR3.2: ' + record.nfr3_2_result + '.', 'saved');
  });
  $('reset').addEventListener('click', () => {
    if (startedAt != null && !confirm('Discard this unfinished task draft? Saved attempts will remain.')) return;
    resetDraft(); message('Task draft reset. Saved attempts remain available for export.');
  });
  function download(content, extension, mime) {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = 'usability-attempts-' + new Date().toISOString().slice(0, 10) + '.' + extension;
    link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  $('csv').addEventListener('click', () => download('\uFEFF' + kit.toCsv(records), 'csv', 'text/csv;charset=utf-8'));
  $('json').addEventListener('click', () => download(JSON.stringify({
    schema_version: 1, exported_at: new Date().toISOString(),
    note: 'Observed usability attempts and facilitator dry runs are explicitly distinguished. These are not questionnaire responses.',
    records,
  }, null, 2), 'json', 'application/json'));

  let restored;
  try { restored = JSON.parse(localStorage.getItem(storageKey) || 'null'); }
  catch (_) { message('Previous local data could not be read. Do not clear browser storage if you need to recover it.', 'error'); }
  if (Array.isArray(restored?.records)) records = restored.records;
  const draft = restored?.draft;
  if (draft?.fields) {
    const v = draft.fields;
    $('role').value = v.role === 'Provider' ? 'Provider' : 'Owner';
    updateRole(v.task);
    for (const id of fieldIds) if (id in v && id !== 'role' && id !== 'task') {
      if ($(id).type === 'checkbox') $(id).checked = Boolean(v[id]);
      else $(id).value = v[id];
    }
    startedAt = draft.startedAt; endedAt = draft.endedAt; lockedMeta = draft.lockedMeta;
    sessionId = draft.sessionId || sessionId;
  } else updateRole();
  updateTask(); updateTimer(); renderRecords();
  setInterval(updateTimer, 500);
})();
