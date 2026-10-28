"""Add a small, labelled UAT dataset to the existing isolated Staging pair.

No new users/passwords, production writes, schema changes or fabricated payment
records. Historic dates are synthetic; completion still requires the deployed
image validator and the normal completion RPC. Repeating a finished batch only
verifies it. All runtime SQL/manifests stay in the ignored private output folder.
"""
import argparse
import hashlib
import io
import json
import re
import subprocess
import time
import uuid
from collections import Counter
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

ROOT = Path(__file__).resolve().parent.parent
REF = 'gqtetdavmrautoojaqrk'
BASE = f'https://{REF}.supabase.co'
PRIVATE = ROOT / 'output/staging-private'
MANIFEST = PRIVATE / 'uat-dataset-v1.local.json'
CLI = ROOT / 'tool/backend-cli/node_modules/.bin/supabase.cmd'
MYT = timezone(timedelta(hours=8))
TAG = '[UAT]'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class ApiFailure(Exception):
    def __init__(self, status, code, retry=0):
        self.status, self.code, self.retry = status, code, retry
        super().__init__(f'HTTP {status}; code {code}. No response body logged.')


def sql_literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def uid(value):
    parsed = uuid.UUID(value)
    if str(parsed) != value:
        raise ValueError('Canonical UUID required.')
    return sql_literal(value) + '::uuid'


def stamp(value):
    return sql_literal(value) + '::timestamptz'


def read_context():
    cfg = json.loads((ROOT / 'supabase/backend_config.staging.local.json').read_text(encoding='utf-8-sig'))
    fixture = json.loads((PRIVATE / 'booking-fixture.local.json').read_text(encoding='utf-8-sig'))
    assert cfg['APP_ENV'] == fixture['environment'] == 'staging'
    assert cfg['SUPABASE_PROJECT_REF'] == fixture['project_ref'] == REF
    assert cfg['SUPABASE_URL'] == BASE and cfg['ALLOW_PRODUCTION_BACKEND'] is False
    assert fixture['fixture'] == 'isolated-booking-run-v1'
    uuid.UUID(fixture['run_id'])
    assert len(fixture['accounts']) == 2
    for account in fixture['accounts']:
        assert account['email'] == f"{account['role']}.{fixture['run_id']}@rental-test.invalid"
        uid(account['user_id'])
    return cfg, fixture


class Dataset:
    def __init__(self):
        self.config, self.fixture = read_context()
        self.accounts = {a['role']: a for a in self.fixture['accounts']}
        self.owner = self.accounts['owner']['user_id']
        self.provider = self.accounts['provider']['user_id']
        self.tokens = {}
        self.opener = build_opener(NoRedirect)
        self.serial = 0

    def guard(self):
        run = uid(self.fixture['run_id'])
        return f"""
do $guard$ begin
 perform public.require_test_environment('{REF}');
 if current_user <> 'postgres' then raise exception 'Administrator session required'; end if;
 if not exists(select 1 from public.test_data_run where run_id={run}
  and owner_id={uid(self.owner)} and provider_id={uid(self.provider)} and project_ref='{REF}')
 then raise exception 'Existing isolated fixture pair required'; end if;
 if (select count(*) from auth.users where id in ({uid(self.owner)},{uid(self.provider)})
  and raw_app_meta_data->>'test_run_id'={sql_literal(self.fixture['run_id'])}
  and raw_app_meta_data->>'test_project_ref'='{REF}'
  and raw_app_meta_data->>'synthetic_test_account'='true') <> 2
 then raise exception 'Synthetic Auth identity marker mismatch'; end if;
 if not exists(select 1 from public.provider_profile where provider_id={uid(self.provider)}
  and approval_status='approved') then raise exception 'Approved fixture provider required'; end if;
end $guard$;
"""

    def query(self, sql):
        self.serial += 1
        path = PRIVATE / f'uat-dataset-query-{self.serial}.local.sql'
        path.write_text(sql, encoding='utf-8')
        proc = subprocess.run([str(CLI), 'db', 'query', '--project-ref', REF,
                               '--linked', '--file', str(path), '-o', 'json'],
                              cwd=ROOT, capture_output=True, timeout=90, text=True, encoding='utf-8')
        if proc.returncode:
            # Never echo CLI stderr, SQL responses, token material or DB bodies.
            raise RuntimeError(f'Database operation {self.serial} failed; inspect the private SQL file. No output logged.')
        start = proc.stdout.find('{')
        if start < 0:
            raise RuntimeError('Database response was not structured JSON.')
        data, _ = json.JSONDecoder().raw_decode(proc.stdout[start:])
        return data.get('rows', [])

    def api(self, path, body=None, role=None, raw=False, extra=None):
        assert path.startswith(('/rest/v1/', '/auth/v1/token?', '/functions/v1/evidence-validate', '/storage/v1/object/sign/'))
        headers = {'apikey': self.config['SUPABASE_PUBLISHABLE_KEY']}
        if role:
            headers['Authorization'] = 'Bearer ' + self.token(role)
        headers['Content-Type'] = 'application/octet-stream' if raw else 'application/json'
        headers.update(extra or {})
        payload = body if raw else None if body is None else json.dumps(body).encode()
        request = Request(BASE + path, data=payload, headers=headers)
        try:
            with self.opener.open(request, timeout=45) as response:
                content = response.read()
                return json.loads(content) if content.strip() else None
        except HTTPError as error:
            try:
                problem = json.loads(error.read())
            except Exception:
                problem = {}
            code = problem.get('code', 'unavailable')
            detail = str(problem.get('details', ''))
            retry = re.search(r'retry_after_seconds=(\d+)', detail)
            raise ApiFailure(error.code, code, int(retry.group(1)) if retry else 0) from None

    def token(self, role):
        if role not in self.tokens:
            a = self.accounts[role]
            session = self.api('/auth/v1/token?grant_type=password', {'email': a['email'], 'password': a['password']})
            assert session['user']['id'] == a['user_id']
            self.tokens[role] = session['access_token']
        return self.tokens[role]

    def rpc(self, name, params=None, role='provider'):
        for attempt in range(8):
            try:
                return self.api('/rest/v1/rpc/' + name, params or {}, role)
            except ApiFailure as error:
                if error.code != 'PT429' or attempt == 7:
                    raise
                delay = min(max(error.retry + 1, 2), 55)
                print(json.dumps({'progress': 'Respecting existing rate limit', 'wait_seconds': delay}), flush=True)
                time.sleep(delay)
        raise RuntimeError('Rate-limited request unfinished.')

    def baseline_sql(self, excluded_bookings, excluded_properties):
        bids = ','.join(uid(x) for x in excluded_bookings) or "'00000000-0000-0000-0000-000000000000'::uuid"
        pids = ','.join(uid(x) for x in excluded_properties) or "'00000000-0000-0000-0000-000000000000'::uuid"
        return f"""select jsonb_build_object(
 'properties',(select md5(coalesce(jsonb_agg(to_jsonb(p) order by property_id)::text,'[]')) from public.property p where owner_id={uid(self.owner)} and property_id not in ({pids})),
 'bookings',(select md5(coalesce(jsonb_agg(to_jsonb(b) order by booking_id)::text,'[]')) from public.booking b where (owner_id={uid(self.owner)} or provider_id={uid(self.provider)}) and booking_id not in ({bids})),
 'history',(select md5(coalesce(jsonb_agg(to_jsonb(h) order by status_history_id)::text,'[]')) from public.booking_status_history h join public.booking b using(booking_id) where (b.owner_id={uid(self.owner)} or b.provider_id={uid(self.provider)}) and b.booking_id not in ({bids})),
 'messages',(select md5(coalesce(jsonb_agg(to_jsonb(m) order by message_id)::text,'[]')) from public.booking_message m join public.booking b using(booking_id) where (b.owner_id={uid(self.owner)} or b.provider_id={uid(self.provider)}) and b.booking_id not in ({bids})),
 'profiles',(select md5(coalesce(jsonb_agg(to_jsonb(p) order by provider_id)::text,'[]')) from public.provider_profile p where provider_id={uid(self.provider)}),
 'accounts',(select md5(coalesce(jsonb_agg(to_jsonb(a) order by user_id)::text,'[]')) from public.user_account a where user_id in ({uid(self.owner)},{uid(self.provider)}))
 ) as fingerprint;"""

    def plan(self):
        if MANIFEST.exists():
            plan = json.loads(MANIFEST.read_text(encoding='utf-8'))
            assert plan['project_ref'] == REF and plan['run_id'] == self.fixture['run_id']
            assert plan['owner_id'] == self.owner and plan['provider_id'] == self.provider
            return plan
        rows = self.query('begin;\n' + self.guard() + f"""
select now() as server_now,
 (select jsonb_agg(to_jsonb(p)) from public.provider_weekly_slot p where provider_id={uid(self.provider)}) as slots,
 (select coalesce(jsonb_agg(unavailable_on),'[]') from public.provider_unavailable_date where provider_id={uid(self.provider)}) as unavailable,
 (select jsonb_agg(jsonb_build_object('start',requested_start_at,'end',requested_end_at)) from public.booking where provider_id={uid(self.provider)} and current_status in ('Pending','Accepted','In Progress')) as busy,
 (select jsonb_agg(jsonb_build_object('service_type_id',s.service_type_id,'name',s.name)) from public.service_type s join public.provider_capability c using(service_type_id) where c.provider_id={uid(self.provider)}) as services,
 (select hourly_rate from public.provider_profile where provider_id={uid(self.provider)}) as hourly,
 (select daily_rate from public.provider_profile where provider_id={uid(self.provider)}) as daily;
commit;""")
        info = rows[0]
        now = datetime.fromisoformat(info['server_now']).astimezone(MYT)
        anchor = now.date()
        namespace = uuid.uuid5(uuid.UUID(self.fixture['run_id']), 'uat-dataset-v1')
        ident = lambda name: str(uuid.uuid5(namespace, name))
        services = {s['name']: s['service_type_id'] for s in info['services']}
        assert 'Standard cleaning' in services and 'Deep cleaning' in services
        hourly = Decimal(str(info['hourly'])); daily = Decimal(str(info['daily']))
        assert hourly > 0 and daily > 0
        properties = []
        for i in range(8):
            properties.append({'id': ident(f'property-{i}'), 'unit_name': f'[UAT] {chr(65+i)}-{(i+1)*100+1}',
                               'building_name': ['[UAT] Maple Residence', '[UAT] Lakeview Suites', '[UAT] Garden Apartments', '[UAT] City Court'][i // 2],
                               'address': '[UAT] Fictional rental address, Kuala Lumpur. No real resident or access code.',
                               'bedrooms': [1, 2, 3, 4, 2, 1, 3, 5][i], 'size_sqft': [450, 750, 1050, 1400, 850, 520, 1200, 1650][i]})
        busy = [(datetime.fromisoformat(x['start']), datetime.fromisoformat(x['end'])) for x in info['busy'] or []]
        def interval(day, hours, hour=9):
            start = datetime.combine(day, datetime.min.time(), MYT).replace(hour=hour)
            return start, start + timedelta(hours=hours)
        def available(start, end):
            if start.date().isoformat() in info['unavailable']:
                return False
            return any(s['weekday'] == start.isoweekday() and s['start_time'] <= start.strftime('%H:%M:%S') and s['end_time'] >= end.strftime('%H:%M:%S') for s in info['slots']) and not any(start < b and end > a for a, b in busy)
        bookings = []
        def add(status, day, hours=2, hour=9):
            index = len(bookings)
            start, end = interval(day, hours, hour)
            basis = 'daily' if hours == 8 else 'hourly'
            rate = daily if basis == 'daily' else hourly
            bookings.append({'id': ident(f'booking-{index}'), 'client_id': ident(f'request-{index}'),
                             'property_id': properties[index % 8]['id'], 'service_id': services['Deep cleaning' if index % 3 == 0 else 'Standard cleaning'],
                             'target': status, 'start': start.isoformat(), 'end': end.isoformat(),
                             'created': min(now - timedelta(days=2, minutes=index), start - timedelta(days=2)).isoformat(),
                             'minutes': hours * 60, 'basis': basis, 'rate': str(rate), 'amount': str(rate if basis == 'daily' else rate * hours),
                             'instructions': f'[UAT] Synthetic scenario {index+1}: {status}. Test data only; no real cleaning or payment.'})
        for days, hours in zip([1, 6, 14, 27, 45, 76], [2, 3, 4, 8, 2, 3]):
            candidate = anchor - timedelta(days=days)
            for shift in range(14):
                start, end = interval(candidate - timedelta(days=shift), hours)
                if available(start, end):
                    break
            else:
                raise RuntimeError('Historic sample conflicts with existing availability; choose a different test date.')
            add('Completed', start.date(), hours)
            busy.append((start, end))
        # A deliberately overdue, unfinished task is a valid recovery scenario.
        overdue = anchor if now.hour >= 17 else anchor - timedelta(days=1)
        start, end = interval(overdue, 3, 14)
        assert available(start, end)
        add('In Progress', overdue, 3, 14)
        targets = ['Accepted', 'Pending'] * 5 + ['Pending'] * 3
        for offset in range(1, 61):
            if not targets:
                break
            day = anchor + timedelta(days=offset)
            start, end = interval(day, 2)
            if available(start, end):
                add(targets.pop(0), day)
                busy.append((start, end))
        assert not targets
        for target, offset in [('Cancelled', 4), ('Cancelled', 11), ('Declined', 8), ('Declined', 18)]:
            add(target, anchor - timedelta(days=offset))
        assert len(bookings) == 24
        fingerprint = self.query(self.baseline_sql([b['id'] for b in bookings], [p['id'] for p in properties]))[0]['fingerprint']
        plan = {'version': 1, 'project_ref': REF, 'run_id': self.fixture['run_id'], 'batch_id': str(namespace),
                'source': 'SYNTHETIC UAT DATA - NO REAL SERVICE OR PAYMENT', 'anchor_day': anchor.isoformat(),
                'owner_id': self.owner, 'provider_id': self.provider, 'properties': properties, 'bookings': bookings,
                'baseline': fingerprint, 'finished': False}
        MANIFEST.write_text(json.dumps(plan, indent=2), encoding='utf-8')
        return plan

    def prepare(self, plan):
        statements = ['begin;', self.guard()]
        for p in plan['properties']:
            statements.append(f"""do $row$ begin
 if exists(select 1 from public.property where property_id={uid(p['id'])} and owner_id<>{uid(self.owner)}) then raise exception 'Property identity collision'; end if;
 insert into public.property(property_id,owner_id,unit_name,building_name,address,bedrooms,size_sqft,cleaning_window_start,cleaning_window_end)
 values({uid(p['id'])},{uid(self.owner)},{sql_literal(p['unit_name'])},{sql_literal(p['building_name'])},{sql_literal(p['address'])},{p['bedrooms']},{p['size_sqft']},'08:00','18:00') on conflict(property_id) do nothing;
end $row$;""")
        for b in plan['bookings']:
            statements.append(f"""do $row$ declare changed integer; begin
 if exists(select 1 from public.booking where booking_id={uid(b['id'])}) then
  if not exists(select 1 from public.booking where booking_id={uid(b['id'])} and owner_id={uid(self.owner)} and provider_id={uid(self.provider)} and client_request_id={uid(b['client_id'])}) then raise exception 'Booking identity collision'; end if;
 else
  insert into public.booking(booking_id,client_request_id,owner_id,provider_id,property_id,service_type_id,requested_start_at,requested_end_at,instructions,created_at,quote_basis,quoted_rate,quoted_duration_minutes,quoted_amount)
  values({uid(b['id'])},{uid(b['client_id'])},{uid(self.owner)},{uid(self.provider)},{uid(b['property_id'])},{uid(b['service_id'])},{stamp(b['start'])},{stamp(b['end'])},{sql_literal(b['instructions'])},{stamp(b['created'])},{sql_literal(b['basis'])},{b['rate']},{b['minutes']},{b['amount']});
  update public.booking_status_history set changed_at={stamp(b['created'])} where booking_id={uid(b['id'])};
  perform set_config('request.jwt.claim.sub',{sql_literal(self.provider)},true);
""")
            if b['target'] == 'Accepted':
                statements.append(f"perform public.accept_pending_booking({uid(b['id'])});")
            elif b['target'] in ('Completed', 'In Progress'):
                statements.append(f"""update public.booking set current_status='Accepted' where booking_id={uid(b['id'])};
insert into public.booking_status_history(booking_id,changed_by_user_id,previous_status,new_status,change_reason,changed_at)
 values({uid(b['id'])},{uid(self.provider)},'Pending','Accepted','[UAT] Historical fixture acceptance',{stamp(b['start'])}-interval '1 day');
perform public.transition_booking({uid(b['id'])},'In Progress','[UAT] Synthetic service started');
update public.booking_status_history set changed_at={stamp(b['start'])} where booking_id={uid(b['id'])} and new_status='In Progress';""")
            elif b['target'] in ('Cancelled', 'Declined'):
                actor = self.owner if b['target'] == 'Cancelled' else self.provider
                statements.append(f"""perform set_config('request.jwt.claim.sub',{sql_literal(actor)},true);
perform public.transition_booking({uid(b['id'])},{sql_literal(b['target'])},'[UAT] Schedule changed during acceptance testing');
update public.booking_status_history set changed_at={stamp(b['start'])}-interval '1 day' where booking_id={uid(b['id'])} and new_status={sql_literal(b['target'])};""")
            statements.append('end if; end $row$;')
        statements.extend(['commit;', "select 'Prepared labelled UAT rows' as result;"])
        self.query('\n'.join(statements))
        print(json.dumps({'progress': 'Prepared dataset', 'new_properties': 8, 'planned_bookings': 24}), flush=True)

    @staticmethod
    def photo(kind):
        from PIL import Image, ImageDraw
        image = Image.new('RGB', (480, 280), '#edf2f9')
        draw = ImageDraw.Draw(image)
        draw.rectangle((24, 24, 455, 255), outline='#24366d', width=3)
        draw.text((40, 42), 'SYNTHETIC UAT TEST IMAGE', fill='#24366d')
        draw.text((40, 80), kind.upper() + ' CLEANING - FICTIONAL EXAMPLE', fill='#24366d')
        draw.text((40, 110), 'No real home, resident or cleaning service.', fill='#24366d')
        for i in range(8 if kind == 'before' else 2):
            left = 55 + i * 43
            draw.rectangle((left, 175, left + 20, 204), fill='#7184a8')
        data = io.BytesIO(); image.save(data, format='PNG', optimize=True)
        return data.getvalue()

    def complete(self, plan):
        for index, b in enumerate(x for x in plan['bookings'] if x['target'] == 'Completed'):
            current = self.api('/rest/v1/booking?select=current_status&booking_id=eq.' + b['id'], role='provider')[0]
            if current['current_status'] != 'Completed':
                assert current['current_status'] == 'In Progress'
                for kind in ['before', 'after']:
                    photo_id = str(uuid.uuid5(uuid.UUID(plan['batch_id']), b['id'] + ':' + kind))
                    data = self.photo(kind)
                    self.rpc('begin_evidence_upload', {'p_booking_id': b['id'], 'p_upload_id': photo_id,
                             'p_kind': kind, 'p_extension': 'png', 'p_byte_size': len(data),
                             'p_sha256': hashlib.sha256(data).hexdigest(), 'p_expected_previous_path': None})
                    verified = self.api('/functions/v1/evidence-validate', data, 'provider', True,
                                        {'x-booking-id': b['id'], 'x-upload-id': photo_id})
                    assert verified.get('verified') is True and verified['path'].startswith(b['id'] + '/')
                    result = self.rpc('attach_evidence_upload', {'p_booking_id': b['id'], 'p_upload_id': photo_id})
                    assert result.get('attached') is True
                self.rpc('save_evidence_remarks', {'p_booking_id': b['id'], 'p_remarks': '[UAT] Synthetic completion scenario. Images are generated test fixtures; no real cleaning or payment.'})
                self.rpc('transition_booking', {'p_booking_id': b['id'], 'p_new_status': 'Completed', 'p_reason': '[UAT] Fixture completion verified'})
            # Backfill only this new synthetic event for range-report testing;
            # never change existing user records, verification facts or byte hashes.
            self.query('begin;\n' + self.guard() + f"""
update public.booking_status_history set changed_at={stamp(b['end'])}+interval '15 minutes'
 where booking_id={uid(b['id'])} and new_status='Completed';
commit; select 'Historic UAT completion dated' as result;""")
            print(json.dumps({'progress': 'Verified synthetic completion', 'done': index + 1, 'total': 6}), flush=True)

    def conversations(self, plan):
        threads = [b for b in plan['bookings'] if b['target'] == 'Completed'][:2]
        threads += [b for b in plan['bookings'] if b['target'] == 'Accepted'][:3]
        threads += [b for b in plan['bookings'] if b['target'] == 'In Progress']
        assert len(threads) == 6
        for b in threads:
            for role, text in [('owner', '[UAT] Please focus on the kitchen and living area. This is a test request.'),
                               ('provider', '[UAT] Understood. I will confirm the agreed scope before starting. Test reply only.')]:
                message_id = str(uuid.uuid5(uuid.UUID(plan['batch_id']), b['id'] + ':message:' + role))
                self.rpc('send_booking_message', {'p_booking_id': b['id'], 'p_client_message_id': message_id, 'p_body': text}, role)
            if b['target'] == 'Completed':
                self.query('begin;\n' + self.guard() + f"""
update public.booking_message set created_at={stamp(b['start'])}+interval '30 minutes'
 where booking_id={uid(b['id'])} and sender_user_id={uid(self.owner)};
update public.booking_message set created_at={stamp(b['start'])}+interval '35 minutes'
 where booking_id={uid(b['id'])} and sender_user_id={uid(self.provider)};
commit; select 'Historic UAT conversation dated' as result;""")
        print(json.dumps({'progress': 'Seeded real booking conversations', 'threads': len(threads), 'messages': 12}), flush=True)

    def verify(self, plan):
        bids = ','.join(uid(b['id']) for b in plan['bookings'])
        pids = ','.join(uid(p['id']) for p in plan['properties'])
        rows = self.query('begin;\n' + self.guard() + f"""
select (select count(*) from public.property where property_id in ({pids})) as properties,
 (select jsonb_object_agg(current_status,n) from (select current_status,count(*) n from public.booking where booking_id in ({bids}) group by current_status) s) as statuses,
 (select count(*) from public.booking_message where booking_id in ({bids})) as messages,
 (select count(*) from public.evidence_upload u join app_private.evidence_validation v using(upload_id) where u.booking_id in ({bids}) and u.state='attached' and v.state='verified') as verified_photos,
 (select count(*) from public.booking where booking_id in ({bids}) and (quoted_amount is null or quoted_duration_minutes<>extract(epoch from(requested_end_at-requested_start_at))/60)) as bad_quotes,
 (select count(*) from public.booking_status_history where booking_id in ({bids}) and changed_at>now()) as future_events;
commit;""")
        totals = rows[0]
        assert totals['properties'] == 8 and totals['statuses'] == dict(Counter(b['target'] for b in plan['bookings']))
        assert totals['messages'] == 12 and totals['verified_photos'] == 12
        assert totals['bad_quotes'] == 0 and totals['future_events'] == 0
        baseline = self.query(self.baseline_sql([b['id'] for b in plan['bookings']], [p['id'] for p in plan['properties']]))[0]['fingerprint']
        assert baseline == plan['baseline'], 'Existing business rows changed during this batch; review before claiming completion.'
        earnings = {}
        for period in ['last30', 'thisMonth', 'allTime']:
            report = self.rpc('provider_earnings', {'p_period': period})
            assert report['provider_id'] == self.provider
            assert Decimal(str(report['gross'])) == sum(Decimal(str(bucket['gross'])) for bucket in report['buckets'])
            earnings[period] = {'jobs': report['jobs'], 'gross_myr': report['gross'], 'buckets': len(report['buckets'])}
        assert earnings['allTime']['jobs'] > earnings['last30']['jobs'] >= earnings['thisMonth']['jobs']
        assert earnings['allTime']['buckets'] >= 3
        owner_page = self.rpc('page_owner_booking_search', {'p_query': '[UAT]', 'p_limit': 20}, 'owner')
        assert len(owner_page['items']) == 20 and owner_page['has_more'] is True
        cursor = owner_page['next_cursor']
        next_page = self.rpc('page_owner_booking_search', {'p_query': '[UAT]', 'p_limit': 20, 'p_before_at': cursor['timestamp'], 'p_before_id': cursor['id']}, 'owner')
        assert len(next_page['items']) == 4 and next_page['has_more'] is False
        assert not ({x['booking_id'] for x in owner_page['items']} & {x['booking_id'] for x in next_page['items']})
        # Both participants can read the newly created conversation records.
        target = next(b for b in plan['bookings'] if b['target'] == 'Accepted')
        for role in ['owner', 'provider']:
            messages = self.api('/rest/v1/booking_message?select=message_id,body&booking_id=eq.' + target['id'], role=role)
            assert len(messages) == 2 and all(m['body'].startswith(TAG) for m in messages)
        # Seeded closed and pending examples must preserve normal chat rules.
        for state in ['Completed', 'Pending']:
            closed = next(b for b in plan['bookings'] if b['target'] == state)
            message_id = str(uuid.uuid5(uuid.UUID(plan['batch_id']), 'forbidden-chat:' + state))
            try:
                self.rpc('send_booking_message', {'p_booking_id': closed['id'], 'p_client_message_id': message_id,
                                                 'p_body': '[UAT] This message must be rejected.'})
            except ApiFailure as error:
                assert error.code == '23514'
            else:
                raise RuntimeError('Chat incorrectly accepted a new message in a closed or pending thread.')
        evidence = self.api('/rest/v1/booking_evidence?select=before_path,after_path&booking_id=eq.' + plan['bookings'][0]['id'], role='owner')[0]
        # Verify real participant access to a stored canonical image; never print its URL.
        signed = self.api('/storage/v1/object/sign/cleaning-evidence/' + evidence['before_path'], {'expiresIn': 60}, 'owner')
        assert signed.get('signedURL') or signed.get('signedUrl')
        result = {'status': 'PASS', 'project_ref': REF, 'added': totals, 'earnings': earnings,
                  'old_business_data_unchanged': True, 'new_accounts': 0, 'schema_changes': 0,
                  'production_writes': 0, 'payments_created': 0, 'paging': '20 + 4 without duplicates',
                  'both_role_chat_read': True, 'owner_photo_access': True,
                  'completed_and_pending_chat_writes_denied': True}
        (PRIVATE / 'uat-dataset-result.local.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['plan', 'apply', 'verify'], default='plan', nargs='?')
    parser.add_argument('--confirm-project', default='')
    args = parser.parse_args()
    if args.mode == 'apply' and args.confirm_project != REF:
        parser.error('Apply requires --confirm-project with the exact isolated Staging ref.')
    task = Dataset()
    plan = task.plan()
    if args.mode == 'plan':
        print(json.dumps({'mode': 'READ_ONLY_PLAN', 'project_ref': REF, 'anchor_day': plan['anchor_day'],
                          'properties': len(plan['properties']), 'bookings': dict(Counter(b['target'] for b in plan['bookings'])),
                          'conversations': 6, 'messages': 12, 'verified_synthetic_photos': 12,
                          'new_accounts': 0, 'schema_changes': 0, 'existing_finished_batch': plan['finished']}))
        return
    if args.mode == 'apply' and not plan['finished']:
        task.prepare(plan)
        task.conversations(plan)
        task.complete(plan)
    result = task.verify(plan)
    if args.mode == 'apply':
        plan['finished'] = True
        MANIFEST.write_text(json.dumps(plan, indent=2), encoding='utf-8')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'status': 'INCOMPLETE', 'kind': type(error).__name__,
                          'detail': str(error) if isinstance(error, (ApiFailure, RuntimeError)) else 'Validation failed; no credentials or server bodies logged.',
                          'resume': 'Keep the same private manifest. Do not rotate accounts or invent a new batch.'}), flush=True)
        raise SystemExit(1)
