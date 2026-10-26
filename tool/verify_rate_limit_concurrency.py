"""Real concurrent PostgreSQL sessions, ONLY in the labelled network-none test container."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

OWNER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
PROVIDER = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
BOOK1 = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1'
BOOK2 = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2'


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise RuntimeError('Invalid local test arguments')


def run(container=None, native_bin=None, native_data=None, native_port=None):
    if native_bin is not None:
        # Only our newly created local synthetic cluster. Never accept a URL,
        # arbitrary host, database or user's existing PostgreSQL data directory.
        root = (Path(__file__).resolve().parent.parent / 'output').resolve()
        data = Path(native_data).resolve()
        if data.parent != root or not re.fullmatch(r'pg-verify-[a-f0-9]{32}', data.name):
            raise RuntimeError('Synthetic local data directory required')
        executable = Path(native_bin).resolve() / 'psql.exe'
        if not executable.is_file() or not 1024 <= int(native_port) <= 65535:
            raise RuntimeError('Explicit local PostgreSQL binary/port required')
        command = [str(executable), '-h', '127.0.0.1', '-p', str(native_port),
                   '-U', 'postgres', '-d', 'postgres', '-X', '-A', '-t', '-q', '-v', 'ON_ERROR_STOP=1']
        actual = subprocess.run(command + ['-c', 'show data_directory'], check=True,
                                capture_output=True, text=True, timeout=10).stdout.strip()
        if Path(actual).resolve() != data:
            raise RuntimeError('Local PostgreSQL data directory mismatch')
        return run_checks(command)
    if not re.fullmatch('[a-f0-9]{64}', container):
        raise RuntimeError('Local test container required')
    inspected = subprocess.run(['docker', 'inspect', container], check=True,
                               capture_output=True, text=True, timeout=15)
    metadata = json.loads(inspected.stdout)[0]
    if (metadata['HostConfig']['NetworkMode'] != 'none' or
            not metadata['Name'].startswith('/rental-migration-check-') or
            metadata['Config'].get('Labels', {}).get('rental.verify') != 'network-isolated'):
        raise RuntimeError('Not an approved disposable test container')
    command = ['docker', 'exec', '-i', container, 'psql', '-X', '-A', '-t', '-q',
               '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres']
    return run_checks(command)


def run_checks(command):

    def sql(source):
        result = subprocess.run(command, input=source, capture_output=True, text=True, timeout=20)
        if result.returncode:
            raise RuntimeError('Local SQL check failed')
        return result.stdout.strip()

    source = (Path(__file__).resolve().parent.parent / 'supabase/tests/booking_communication_limits.sql').read_text(encoding='utf-8')
    setup = source.split('-- END SYNTHETIC FIXTURE SETUP')[0]
    if '-- END SYNTHETIC FIXTURE SETUP' not in source:
        raise RuntimeError('Synthetic fixture boundary missing')
    sql(setup + f"""
      insert into public.booking_message(booking_id,sender_user_id,client_message_id,body,created_at)
      select '{BOOK1}','{OWNER}',gen_random_uuid(),'SYNTHETIC CONCURRENT FIXTURE',clock_timestamp()
      from generate_series(1,7);
      insert into public.evidence_upload(upload_id,booking_id,provider_id,kind,object_path,byte_size,sha256,created_at)
      select gen_random_uuid(),'{BOOK1}','{PROVIDER}','before','synthetic-concurrent-'||i,128,repeat('a',64),clock_timestamp()
      from generate_series(1,5) i;
      commit;
    """)

    for action, actor, prefix, expected_count in [('message', OWNER, '33333333', 8), ('evidence', PROVIDER, '44444444', 6)]:
        first_id = f'{prefix}-3333-4333-8333-000000000001'
        second_id = f'{prefix}-3333-4333-8333-000000000002'
        def call(booking, token):
            if action == 'message':
                return f"public.send_booking_message('{booking}','{token}','SYNTHETIC CONCURRENT REQUEST')"
            return f"public.begin_evidence_upload('{booking}','{token}','before','png',128,repeat('a',64))"

        def worker(label, booking, token, hold):
            return f"""begin isolation level read committed;
            set application_name='{label}'; set local role authenticated;
            select set_config('request.jwt.claim.sub','{actor}',true);
            do $$ begin
              perform {call(booking, token)};
              raise notice 'RATE_RESULT:accepted';
            exception when sqlstate 'PT429' then raise notice 'RATE_RESULT:limited'; end $$;
            {"select pg_sleep(3);" if hold else ""}
            commit;"""

        processes = []
        try:
            a = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(a)
            a.stdin.write(worker('rental_rate_A', BOOK1, first_id, True)); a.stdin.close(); a.stdin = None
            until = time.monotonic() + 5
            while sql("select exists(select 1 from pg_stat_activity where application_name='rental_rate_A' and state='active' and query like '%pg_sleep%');") != 't':
                if time.monotonic() > until: raise RuntimeError('First worker did not hold its transaction')
                time.sleep(0.03)
            b = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(b)
            b.stdin.write(worker('rental_rate_B', BOOK2, second_id, False)); b.stdin.close(); b.stdin = None
            # Observe actual contention, not merely two sequential commands.
            until = time.monotonic() + 2
            while sql("select exists(select 1 from pg_stat_activity a join pg_locks l on l.pid=a.pid where a.application_name='rental_rate_B' and l.locktype='advisory' and not l.granted);") != 't':
                if time.monotonic() > until: raise RuntimeError('No overlapping advisory-lock wait observed')
                time.sleep(0.03)
            _, a_error = a.communicate(timeout=10)
            _, b_error = b.communicate(timeout=10)
            if a.returncode or b.returncode or 'RATE_RESULT:accepted' not in a_error or 'RATE_RESULT:limited' not in b_error:
                raise RuntimeError('Concurrent quota was not enforced')
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill(); process.communicate(timeout=5)
        table = 'booking_message' if action == 'message' else 'evidence_upload'
        if sql(f'select count(*) from public.{table};') != str(expected_count):
            raise RuntimeError('Concurrent quota exceeded')
        # A retry at the full quota reuses the accepted operation, not new work.
        sql(f"begin; set local role authenticated; select set_config('request.jwt.claim.sub','{actor}',true); select {call(BOOK1, first_id)}; commit;")
        if sql(f'select count(*) from public.{table};') != str(expected_count):
            raise RuntimeError('Retry consumed quota twice')
    # Competing trusted workers must share one lease, not decode twice.
    claim = f"public.claim_evidence_validation('{BOOK1}','{first_id}','{PROVIDER}')"
    processes = []
    try:
        a = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        processes.append(a)
        a.stdin.write(f"begin; set application_name='rental_photo_A'; set local role service_role; select {claim}->>'state'; select pg_sleep(3); commit;")
        a.stdin.close(); a.stdin = None
        until = time.monotonic() + 5
        while sql("select exists(select 1 from pg_stat_activity where application_name='rental_photo_A' and state='active' and query like '%pg_sleep%');") != 't':
            if time.monotonic() > until: raise RuntimeError('Photo worker did not hold its transaction')
            time.sleep(0.03)
        b = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        processes.append(b)
        b.stdin.write(f"begin; set application_name='rental_photo_B'; set local role service_role; select {claim}->>'state'; commit;")
        b.stdin.close(); b.stdin = None
        until = time.monotonic() + 2
        while sql("select exists(select 1 from pg_stat_activity a join pg_locks l on l.pid=a.pid where a.application_name='rental_photo_B' and not l.granted);") != 't':
            if time.monotonic() > until: raise RuntimeError('No concurrent photo lock observed')
            time.sleep(0.03)
        a_out, _ = a.communicate(timeout=10)
        b_out, _ = b.communicate(timeout=10)
        if a.returncode or b.returncode or 'processing' not in a_out or 'busy' not in b_out:
            raise RuntimeError('Photo lease was not exclusive')
        if sql(f"select attempts from app_private.evidence_validation where upload_id='{first_id}';") != '1':
            raise RuntimeError('Concurrent photo attempt consumed twice')
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill(); process.communicate(timeout=5)
    print('Local concurrent checks passed: chat/upload quotas and exclusive photo-validation lease; retries remained idempotent.')


def main():
    try:
        parser = SafeParser(description=__doc__)
        group = parser.add_mutually_exclusive_group(required=True)
        group.add_argument('--container')
        group.add_argument('--native-bin')
        parser.add_argument('--native-data')
        parser.add_argument('--native-port', type=int)
        args = parser.parse_args()
        run(args.container, args.native_bin, args.native_data, args.native_port)
        return 0
    except Exception:
        print('Local concurrent rate checks failed or were incomplete. No raw SQL or private output is printed.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
