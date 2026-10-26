"""Contention checks against ONLY a newly created loopback synthetic cluster."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import time


def run(native_bin, native_data, native_port):
    root = (Path(__file__).resolve().parent.parent / 'output').resolve()
    data = Path(native_data).resolve()
    executable = Path(native_bin).resolve() / 'psql.exe'
    if data.parent != root or not re.fullmatch(r'pg-verify-[a-f0-9]{32}', data.name):
        raise RuntimeError('Disposable local data directory required')
    if not executable.is_file() or not 1024 <= native_port <= 65535:
        raise RuntimeError('Explicit local PostgreSQL binary/port required')
    command = [str(executable), '-h', '127.0.0.1', '-p', str(native_port), '-U', 'postgres',
               '-d', 'postgres', '-X', '-A', '-t', '-q', '-v', 'ON_ERROR_STOP=1']

    def sql(source):
        result = subprocess.run(command, input=source, capture_output=True, text=True, timeout=15)
        if result.returncode:
            raise RuntimeError('Synthetic SQL failed')
        return result.stdout.strip()

    if Path(sql('show data_directory')).resolve() != data:
        raise RuntimeError('Synthetic local cluster mismatch')
    owner = 'd1111111-1111-4111-8111-111111111111'
    provider = 'd2222222-2222-4222-8222-222222222222'
    run_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
    project = 'aaaaaaaaaaaaaaaaaaaa'
    sql(f"""
      update public.app_deployment_environment set environment='staging',project_ref='{project}';
      insert into auth.users(id,email) values ('{owner}','owner.{run_id}@rental-test.invalid'),
        ('{provider}','provider.{run_id}@rental-test.invalid');
      select public.seed_test_fixture('{project}','{run_id}','{owner}','{provider}',
        (now() at time zone 'Asia/Kuala_Lumpur')::date+7);
    """)
    booking = sql(f"select booking_id from public.booking where owner_id='{owner}'")
    for case in ('stale', 'accepted'):
        fingerprint = sql(f"select public.preview_test_fixture_cleanup('{project}','{run_id}')->>'fingerprint'")
        processes = []
        try:
            a = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(a)
            mutation = (f"update public.booking set instructions='[TEST] Concurrent edit' where booking_id='{booking}';"
                        if case == 'stale' else f"set local role authenticated;select set_config('request.jwt.claim.sub','{provider}',true);"
                        f"select public.accept_pending_booking('{booking}');")
            a.stdin.write(f"begin;set application_name='fixture_cleanup_A';{mutation}select pg_sleep(3);commit;")
            a.stdin.close()
            a.stdin = None
            until = time.monotonic() + 5
            while sql("select exists(select 1 from pg_stat_activity where application_name='fixture_cleanup_A' "
                      "and state='active' and query like '%pg_sleep%')") != 't':
                if time.monotonic() > until:
                    raise RuntimeError('Mutation did not hold its lock')
                time.sleep(.03)
            b = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(b)
            expected = 'serialization_failure' if case == 'stale' else 'insufficient_privilege'
            b.stdin.write(f"""begin;set application_name='fixture_cleanup_B';set local role service_role;
              do $$begin
                perform public.cleanup_test_fixture('{project}','{run_id}','{fingerprint}');
                raise exception 'Unexpected cleanup';
              exception when {expected} then raise notice 'CLEANUP_RESULT:refused';end$$;commit;""")
            b.stdin.close()
            b.stdin = None
            until = time.monotonic() + 2
            while sql("select exists(select 1 from pg_stat_activity a join pg_locks l on l.pid=a.pid "
                      "where a.application_name='fixture_cleanup_B' and not l.granted)") != 't':
                if time.monotonic() > until:
                    raise RuntimeError('No actual cleanup contention observed')
                time.sleep(.03)
            a.communicate(timeout=8)
            _, errors = b.communicate(timeout=8)
            if a.returncode or b.returncode or 'CLEANUP_RESULT:refused' not in errors:
                raise RuntimeError('Concurrent cleanup did not refuse safely')
            if sql(f"select count(*) from public.booking where booking_id='{booking}'") != '1':
                raise RuntimeError('Concurrent business data was removed')
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                    process.communicate(timeout=5)
    print('PASS: concurrent fixture edit and real acceptance blocked cleanup; actual lock waits observed, data retained.')


if __name__ == '__main__':
    try:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('--native-bin', required=True)
        parser.add_argument('--native-data', required=True)
        parser.add_argument('--native-port', required=True, type=int)
        args = parser.parse_args()
        run(args.native_bin, args.native_data, args.native_port)
    except Exception:
        print('Synthetic cleanup concurrency checks failed. No private SQL/credentials printed.')
        sys.exit(1)
