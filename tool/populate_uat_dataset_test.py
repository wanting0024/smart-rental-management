"""Offline checks for Staging-only identity, date/quote and retry boundaries."""
import copy
import json
import unittest
from datetime import datetime
from decimal import Decimal
from unittest.mock import Mock, patch

import populate_uat_dataset as seed


class UatDatasetTests(unittest.TestCase):
    def task(self):
        task = seed.Dataset.__new__(seed.Dataset)
        task.owner = '11111111-1111-4111-8111-111111111111'
        task.provider = '22222222-2222-4222-8222-222222222222'
        task.fixture = {'run_id': '33333333-3333-4333-8333-333333333333'}
        info = {'server_now': '2026-10-26T15:00:00+00:00',
                'slots': [{'weekday': d, 'start_time': '08:00:00', 'end_time': '18:00:00'} for d in range(1, 8)],
                'unavailable': ['2026-10-29'],
                'busy': [{'start': '2026-10-25T02:00:00+00:00', 'end': '2026-10-25T04:00:00+00:00'},
                         {'start': '2026-10-27T01:00:00+00:00', 'end': '2026-10-27T04:00:00+00:00'}],
                'services': [{'name': 'Standard cleaning', 'service_type_id': '44444444-4444-4444-8444-444444444444'},
                             {'name': 'Deep cleaning', 'service_type_id': '55555555-5555-4555-8555-555555555555'}],
                'hourly': 40, 'daily': 280}
        task.query = Mock(side_effect=[[info], [{'fingerprint': {'original': 'unchanged'}}]])
        return task

    def plan(self, task=None):
        task = task or self.task()
        manifest = Mock()
        manifest.exists.return_value = False
        with patch.object(seed, 'MANIFEST', manifest):
            result = task.plan()
        return task, manifest, result

    def test_dates_avoid_busy_days_and_unavailable_dates(self):
        _, _, plan = self.plan()
        completed = [b for b in plan['bookings'] if b['target'] == 'Completed']
        self.assertEqual(datetime.fromisoformat(completed[0]['start']).day, 24)
        future = [b for b in plan['bookings'] if b['target'] in ('Accepted', 'Pending')]
        days = [datetime.fromisoformat(b['start']).date().isoformat() for b in future]
        self.assertNotIn('2026-10-27', days)
        self.assertNotIn('2026-10-29', days)
        self.assertEqual(len(days), len(set(days)))
        for b in plan['bookings']:
            self.assertLess(datetime.fromisoformat(b['created']), datetime.fromisoformat(b['start']))

    def test_quotes_match_duration_and_daily_is_eight_hours(self):
        _, _, plan = self.plan()
        for b in plan['bookings']:
            minutes = (datetime.fromisoformat(b['end']) - datetime.fromisoformat(b['start'])).total_seconds() / 60
            self.assertEqual(minutes, b['minutes'])
            if b['basis'] == 'daily':
                self.assertEqual(minutes, 480)
                self.assertEqual(Decimal(b['amount']), Decimal('280'))
            else:
                self.assertEqual(Decimal(b['amount']), Decimal(b['rate']) * Decimal(b['minutes']) / 60)

    def test_existing_manifest_reuses_ids_without_new_plan_or_query(self):
        task, manifest, plan = self.plan()
        manifest.exists.return_value = True
        manifest.read_text.return_value = json.dumps(plan)
        task.query.reset_mock()
        with patch.object(seed, 'MANIFEST', manifest):
            self.assertEqual(task.plan(), plan)
        task.query.assert_not_called()
        self.assertEqual(len({b['id'] for b in plan['bookings']}), 24)

    def test_mismatched_manifest_is_rejected(self):
        task, manifest, plan = self.plan()
        bad = copy.deepcopy(plan)
        bad['project_ref'] = 'dvakrwalnqpcmgirmlct'
        manifest.exists.return_value = True
        manifest.read_text.return_value = json.dumps(bad)
        with patch.object(seed, 'MANIFEST', manifest), self.assertRaises(AssertionError):
            task.plan()

    def test_unconfigured_endpoint_and_unsafe_uuid_are_rejected(self):
        task = self.task()
        with self.assertRaises(AssertionError):
            task.api('https://example.com/collect')
        with self.assertRaises(ValueError):
            seed.uid("anything'; select secret;")
        self.assertEqual(seed.sql_literal("Unit O'Neil"), "'Unit O''Neil'")

    def test_production_client_configuration_is_rejected_before_network(self):
        cfg = {'APP_ENV': 'production', 'SUPABASE_PROJECT_REF': seed.REF,
               'SUPABASE_URL': seed.BASE, 'ALLOW_PRODUCTION_BACKEND': False}
        fixture = {'environment': 'staging'}
        with patch.object(seed.Path, 'read_text', side_effect=[json.dumps(cfg), json.dumps(fixture)]), self.assertRaises(AssertionError):
            seed.read_context()

    def test_successful_void_rpc_does_not_require_a_json_body(self):
        task = self.task()
        task.config = {'SUPABASE_PUBLISHABLE_KEY': 'unused-test-publishable-value'}
        response = Mock()
        response.read.return_value = b''
        context = Mock()
        context.__enter__ = Mock(return_value=response)
        context.__exit__ = Mock(return_value=False)
        task.opener = Mock()
        task.opener.open.return_value = context
        self.assertIsNone(task.api('/rest/v1/rpc/save_evidence_remarks', {}))

    def test_finished_batch_does_not_repeat_cloud_writes(self):
        task = Mock()
        task.plan.return_value = {'finished': True}
        task.verify.return_value = {'status': 'PASS'}
        with patch.object(seed, 'Dataset', return_value=task), patch.object(seed, 'MANIFEST'), patch('sys.argv', ['seed', 'apply', '--confirm-project', seed.REF]), patch('builtins.print'):
            seed.main()
        task.prepare.assert_not_called()
        task.conversations.assert_not_called()
        task.complete.assert_not_called()
        task.verify.assert_called_once()


if __name__ == '__main__':
    unittest.main()
