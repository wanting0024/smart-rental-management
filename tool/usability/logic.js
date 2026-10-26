(function (root) {
  'use strict';
  const tasks = [
    { id: 'O01', role: 'Owner', title: 'Add a rental unit', requirements: 'FR1.13', prompt: 'You manage a new rental unit. Add its details so you can arrange a cleaning service for it.', setup: 'Use the test unit details supplied by the facilitator. No existing unit with the same test code.', check: 'The unit appears under the signed-in Owner after a refresh; details and cleaning window match the fixture.' },
    { id: 'O02', role: 'Owner', title: 'Make your first cleaning request', requirements: 'FR1.5; NFR3.2', prompt: 'Arrange a two-hour standard cleaning for your test rental unit on the supplied future date, from 10:00 to 12:00 Malaysia time. Tell the provider to focus on the kitchen and bathrooms. Choose a suitable provider and submit the request.', setup: 'Start on authenticated Owner Home. The test unit already exists from O01. An approved Provider supports this service, is available, has no blocking booking and has an hourly rate. This is the participant\'s first booking attempt.', check: 'One server-confirmed Pending request exists with the intended unit, service, time, instructions and quote. Pending is not an accepted appointment. Record guidance and full elapsed time; 5 minutes is the report target.' },
    { id: 'O03', role: 'Owner', title: 'Understand booking progress', requirements: 'FR1.8', prompt: 'Find out whether your cleaning appointment has been confirmed. Show what has changed since you sent the request.', setup: 'The paired Provider has accepted the O02 request.', check: 'The Owner identifies Accepted and finds its status history. Ask what the current status means without explaining it first.' },
    { id: 'O04', role: 'Owner', title: 'Send access instructions', requirements: 'FR1.9', prompt: 'Tell the provider for this booking to use the side entrance. Find the provider\'s reply.', setup: 'An Accepted or In Progress booking and a paired Provider session are ready.', check: 'The message and reply appear in the same booking conversation under the two accounts.' },
    { id: 'O05', role: 'Owner', title: 'Review completed cleaning', requirements: 'FR1.10; FR1.11', prompt: 'The cleaning has finished. Check the submitted work and leave a rating and a short review.', setup: 'The paired Provider has completed the booking with before/after photos and remarks.', check: 'The Owner finds the evidence, understands Completed, and saves a 1-5 rating; refreshed review matches the acknowledged result.' },
    { id: 'O06', role: 'Owner', title: 'Cancel an unaccepted request', requirements: 'FR1.12', prompt: 'You no longer need the separate request that has not yet been accepted. Cancel it and explain why.', setup: 'Use a separate Pending request, not the shared booking being used for other tasks.', check: 'The intended request becomes Cancelled with its reason retained in history; no other booking changes.' },
    { id: 'P01', role: 'Provider', title: 'Set services and working hours', requirements: 'FR2.3', prompt: 'Make your services and working hours reflect the test schedule supplied to you. Also mark the supplied day when you cannot work.', setup: 'Use an approved Provider with no confirmed jobs on the fixture dates. Collect this task before the paired booking session or use a separate future date.', check: 'Service choices, weekly slot and unavailable date remain after refresh; slots meet the agreed two-hour minimum.' },
    { id: 'P02', role: 'Provider', title: 'Review and accept a request', requirements: 'FR2.4; FR2.5', prompt: 'Review the incoming cleaning request for the test unit. Decide whether you can do it and confirm the appointment if you can.', setup: 'O02 has produced a compatible Pending request. Provider availability is still valid.', check: 'The Provider finds the unit, date/time, instructions and quote; acceptance is acknowledged and the Owner sees Accepted. This task does not prove atomicity or RLS.' },
    { id: 'P03', role: 'Provider', title: 'Coordinate with the Owner', requirements: 'FR2.9', prompt: 'Find the Owner\'s access instructions for this booking and reply that you will use the side entrance.', setup: 'O04 has sent a booking-linked message. The booking is Accepted or In Progress.', check: 'The reply reaches the paired Owner in the correct conversation.' },
    { id: 'P04', role: 'Provider', title: 'Record and complete a cleaning job', requirements: 'FR2.5; FR2.6', prompt: 'Record that the cleaning has started. When the simulated work is finished, submit the supplied before/after photos and completion remarks, then complete the job.', setup: 'Use an Accepted test booking at a valid service time and non-identifying test photos. Follow the backend\'s start/completion rules; do not bypass them to make the task pass.', check: 'In Progress precedes Completed. Both photos and remarks are retained and visible to the Owner. Acknowledged completion survives refresh.' },
    { id: 'P05', role: 'Provider', title: 'Read the Owner review', requirements: 'FR2.10 (booking review only)', prompt: 'Find the feedback the Owner left for this completed booking.', setup: 'O05 has saved a review.', check: 'The Provider reads the saved booking rating/comment without being able to edit it. A profile aggregate/review-history requirement is not established by this one view.' },
    { id: 'P06', role: 'Provider', title: 'Decline a separate request', requirements: 'FR2.4; FR2.5', prompt: 'You cannot take the separate Pending request supplied for this task. Let the Owner know through the booking decision.', setup: 'A separate Pending request is available; preserve the main paired booking.', check: 'That request becomes Declined, the Owner sees its outcome and the provider slot is not reserved.' },
  ];

  function evaluateNfr(record, previousRecords = []) {
    if (record.task_id !== 'O02') return 'NOT_APPLICABLE';
    if (record.record_type !== 'OBSERVED_USABILITY_SESSION' ||
        record.mode !== 'CONNECTED_SESSION' || !record.environment_verified ||
        !record.first_booking || !record.prerequisites_ready ||
        record.outcome === 'BLOCKED' || previousRecords.some(previous =>
          previous.task_id === 'O02' && previous.participant_code === record.participant_code &&
          previous.record_type === 'OBSERVED_USABILITY_SESSION')) return 'NOT_EVALUATED';
    if (record.outcome === 'ASSISTED' || record.guidance_count > 0 ||
        record.outcome === 'FAILED') return 'FAIL';
    if (!record.server_confirmed) return 'UNVERIFIED';
    return record.outcome === 'INDEPENDENT' && record.elapsed_seconds <= 300
      ? 'PASS' : 'FAIL';
  }

  function validateRecord(record) {
    const errors = [];
    const task = tasks.find(t => t.id === record.task_id);
    if (!task || task.role !== record.role) errors.push('Choose a task for the selected role.');
    if (!['LOCAL_UI_REVIEW', 'CONNECTED_SESSION'].includes(record.mode)) errors.push('Choose a test mode.');
    if (!['OBSERVED_USABILITY_SESSION', 'FACILITATOR_DRY_RUN'].includes(record.record_type)) errors.push('Choose a record source.');
    if (record.record_type === 'OBSERVED_USABILITY_SESSION' && !/^P\d{2,4}$/.test(record.participant_code || '')) errors.push('Use an anonymous participant code such as P01.');
    if (!['INDEPENDENT', 'ASSISTED', 'FAILED', 'BLOCKED'].includes(record.outcome)) errors.push('Record an outcome.');
    if (!Number.isFinite(record.elapsed_seconds) || record.elapsed_seconds < 0) errors.push('Timer duration is invalid.');
    if (!Number.isInteger(record.guidance_count) || record.guidance_count < 0) errors.push('Guidance count must be a whole number.');
    if (record.outcome === 'INDEPENDENT' && record.guidance_count > 0) errors.push('With external guidance, choose Assisted rather than Independent.');
    if (record.outcome === 'ASSISTED' && record.guidance_count < 1) errors.push('Record at least one instance of external guidance for an Assisted outcome.');
    if (['FAILED', 'BLOCKED'].includes(record.outcome) && !String(record.notes || '').trim()) errors.push('Describe the failure or blocker.');
    if (record.mode === 'CONNECTED_SESSION' && !record.environment_verified && record.outcome !== 'BLOCKED') errors.push('Verify the connected test environment before recording a connected session.');
    if (!String(record.device || '').trim() || !String(record.build || '').trim()) errors.push('Record the device and build identifier.');
    if (record.ease_score !== '' && (!Number.isInteger(record.ease_score) || record.ease_score < 1 || record.ease_score > 5)) errors.push('Ease must be 1-5 or left blank.');
    return errors;
  }

  function csvCell(value) {
    let text = value == null ? '' : String(value);
    if (typeof value === 'string' && /^[=+\-@]/.test(text.trimStart())) text = "'" + text;
    return '"' + text.replace(/"/g, '""') + '"';
  }
  const columns = ['record_id', 'session_id', 'participant_code', 'record_type', 'role',
    'mode', 'environment_verified', 'device', 'build', 'network', 'first_booking',
    'task_id', 'requirements', 'prerequisites_ready', 'started_at', 'ended_at',
    'elapsed_seconds', 'outcome', 'guidance_count', 'server_confirmed', 'ease_score',
    'notes', 'evidence_reference', 'nfr3_2_result'];
  function toCsv(records) {
    return [columns.map(csvCell).join(','),
      ...records.map(r => columns.map(c => csvCell(r[c])).join(','))].join('\r\n');
  }
  const api = { tasks, evaluateNfr, validateRecord, csvCell, toCsv, columns };
  root.UsabilityKit = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(globalThis);
