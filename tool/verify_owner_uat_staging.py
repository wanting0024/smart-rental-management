"""Read-only business checks with existing Staging users; no secret output.

Signs in existing fixed fixture users. Does not create users, edit profiles,
bookings or photos, change server configuration, or persist returned tokens.
"""
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
REF = 'gqtetdavmrautoojaqrk'


def run():
    config = json.loads((ROOT / 'supabase/backend_config.staging.local.json').read_text(encoding='utf-8-sig'))
    fixture = json.loads((ROOT / 'output/staging-private/booking-fixture.local.json').read_text(encoding='utf-8-sig'))
    assert config['APP_ENV'] == fixture['environment'] == 'staging'
    assert config['SUPABASE_PROJECT_REF'] == fixture['project_ref'] == REF
    assert config['SUPABASE_URL'] == f'https://{REF}.supabase.co'
    assert config['ALLOW_PRODUCTION_BACKEND'] is False
    key = config['SUPABASE_PUBLISHABLE_KEY']
    assert key.startswith('sb_publishable_')
    base = config['SUPABASE_URL']

    def request(path, body=None, token=None):
        headers = {'apikey': key, 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = f'Bearer {token}'
        req = Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        try:
            with urlopen(req, timeout=30) as response:
                return response.status, json.load(response)
        except HTTPError as error:
            return error.code, json.loads(error.read())

    status, marker = request('/rest/v1/rpc/get_app_environment', {})
    assert status == 200 and marker['environment'] == 'staging' and marker['project_ref'] == REF
    checked = ['Pinned Staging marker']
    for account in fixture['accounts']:
        status, session = request('/auth/v1/token?grant_type=password', {'email': account['email'], 'password': account['password']})
        assert status == 200 and session['user']['id'] == account['user_id']
        token = session['access_token']
        role = account['role']
        status, catalog = request('/rest/v1/service_type?select=service_type_id,name,description&order=name&limit=20', token=token)
        assert status == 200 and isinstance(catalog, list) and catalog
        assert all(isinstance(row['name'], str) and (row['description'] is None or isinstance(row['description'], str)) for row in catalog)
        checked.append(f'{role.title()} can read service descriptions without extra grants')
        status, summary = request('/rest/v1/rpc/my_owner_portfolio_summary', {}, token)
        if role == 'owner':
            assert status == 200 and summary['actor_id'] == account['user_id']
            assert all(type(summary[k]) is int and summary[k] >= 0 for k in ['property_count', 'building_count', 'size_sqft', 'open', 'done', 'total'])
            status, profile = request('/rest/v1/rpc/my_owner_profile', {}, token)
            assert status == 200 and summary['property_count'] == profile['property_count']
            checked.append('Owner complete portfolio and profile totals agree')
            for statuses in ['Pending', 'Accepted,In%20Progress', 'Completed']:
                status, rows = request('/rest/v1/booking?select=booking_id,owner_id,current_status,created_at&owner_id=eq.' + account['user_id'] + '&current_status=in.(' + statuses + ')&order=created_at.desc,booking_id.desc&limit=21', token=token)
                assert status == 200 and isinstance(rows, list)
                expected = statuses.replace('%20', ' ').split(',')
                assert len(rows) <= 21 and all(r['owner_id'] == account['user_id'] and r['current_status'] in expected for r in rows)
            checked.append('Owner status filters execute before bounded pages')
            status, search = request('/rest/v1/rpc/page_owner_booking_search', {'p_query': '', 'p_group': 'all', 'p_limit': 20}, token)
            assert status == 200 and search['actor_id'] == account['user_id'] and len(search['items']) <= 20
            assert all(row['owner_id'] == account['user_id'] for row in search['items'])
            status, history = request('/rest/v1/rpc/page_owner_booking_search', {'p_group': 'history', 'p_limit': 20}, token)
            assert status == 200 and all(row['current_status'] in ['Completed', 'Cancelled', 'Declined'] for row in history['items'])
            checked.append('Owner full booking search/history is bounded and account scoped')
            status, directory = request('/rest/v1/rpc/page_approved_provider_directory', {'p_limit': 20}, token)
            assert status == 200 and directory['actor_id'] == account['user_id'] and len(directory['items']) <= 20
            safe = {'provider_id', 'listed_at', 'display_name', 'bio', 'service_area', 'hourly_rate', 'daily_rate', 'rating_average', 'completed_job_count', 'services'}
            assert all(set(row) <= safe for row in directory['items'])
            checked.append('Approved directory exposes only named public profile fields')
        else:
            assert status == 403 and summary.get('code') == '42501'
            checked.append('Provider cannot read Owner portfolio')
            for rpc in ['page_owner_booking_search', 'page_approved_provider_directory']:
                status, denial = request('/rest/v1/rpc/' + rpc, {}, token)
                assert status == 403 and denial.get('code') == '42501'
            checked.append('Provider cannot use Owner search/directory interfaces')
    status, _ = request('/rest/v1/rpc/my_owner_portfolio_summary', {})
    assert status >= 400
    checked.append('Anonymous portfolio access denied')
    for rpc in ['page_owner_booking_search', 'page_approved_provider_directory']:
        status, _ = request('/rest/v1/rpc/' + rpc, {})
        assert status >= 400
    checked.append('Anonymous search/directory access denied')
    print(json.dumps({'status': 'PASS', 'checks': checked, 'business_writes': 0, 'new_accounts': 0}))


if __name__ == '__main__':
    try:
        run()
    except Exception:
        print(json.dumps({'status': 'FAIL', 'detail': 'Verification incomplete; no credentials or raw server responses printed.'}))
        raise SystemExit(1)
