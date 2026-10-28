"""Synthetic scanner tests. No real credentials, network services or history mutations."""
import base64
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import security_scan as audit


def secret():
    return 'sb_' + 'secret_' + 'SYNTHETIC' * 5


def jwt(role):
    def part(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
    return part({'alg': 'HS256'}) + '.' + part({'role': role, 'fixture': 'NOT_REAL'}) + '.SYNTHETIC_SIGNATURE'


class ScannerTests(unittest.TestCase):
    def test_public_key_allowed_but_private_keys_and_user_sessions_blocked(self):
        self.assertFalse(list(audit.findings_in_text('sb_publishable_public_fixture')))
        self.assertFalse(list(audit.findings_in_text(jwt('anon'))))
        for value, rule in ((secret(), 'SUPABASE_SECRET'), (jwt('service_role'), 'SERVICE_ROLE_JWT'),
                            (jwt('authenticated'), 'USER_SESSION_JWT'),
                            ('sk_' + 'test_' + 'SYNTHETIC' * 4, 'STRIPE_SECRET')):
            self.assertIn(rule, {item[0] for item in audit.findings_in_text(value)})

    def test_stream_matches_across_chunk_boundary_and_utf16(self):
        for encoded in (secret().encode(), secret().encode('utf-16le')):
            scanner = audit.Scanner()
            scanner.stream(io.BytesIO(b'x' * (1024 * 1024 - 5) + encoded), 'fixture.bin')
            self.assertTrue(any(item[1] == 'SUPABASE_SECRET' for item in scanner.findings))

    def test_invalid_binary_separators_do_not_join_unrelated_string_literals(self):
        prefix = 'sb_' + 'secret_'
        suffix = 'SYNTHETIC' * 5
        for payload in (prefix.encode() + b'\xff' + suffix.encode(),
                        prefix.encode('utf-16le') + b'\x00\xd8' + suffix.encode('utf-16le')):
            scanner = audit.Scanner()
            scanner.stream(io.BytesIO(payload), 'synthetic-string-pool.bin')
            self.assertFalse(any(item[1] == 'SUPABASE_SECRET' for item in scanner.findings))

    def test_real_key_is_detected_between_malformed_binary_bytes(self):
        for payload in (b'\xff' + secret().encode() + b'\xfe',
                        b'\x00\xd8' + secret().encode('utf-16le') + b'\x00\xd8'):
            scanner = audit.Scanner()
            scanner.stream(io.BytesIO(payload), 'synthetic-key.bin')
            self.assertTrue(any(item[1] == 'SUPABASE_SECRET' for item in scanner.findings))

    def test_zip_members_scanned_without_extracting(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('lib/arm64-v8a/libapp.so', b'\0' + secret().encode() + b'\0')
        scanner = audit.Scanner()
        scanner.archive(io.BytesIO(data.getvalue()), 'fixture.apk')
        self.assertTrue(any('libapp.so' in item[0] for item in scanner.findings))

    def test_corruption_and_resource_limits_fail_closed(self):
        with self.assertRaises(zipfile.BadZipFile):
            audit.Scanner().archive(io.BytesIO(b'not an apk'), 'fixture.apk')
        with patch.object(audit, 'MAX_FILE', 8):
            with self.assertRaises(audit.ScanIncomplete):
                audit.Scanner().stream(io.BytesIO(b'x' * 16), 'fixture')

    def test_private_container_in_artifact_blocks_even_without_plaintext_key(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('assets/private-signing.p12', b'opaque synthetic binary')
        scanner = audit.Scanner()
        scanner.archive(io.BytesIO(data.getvalue()), 'fixture.apk')
        self.assertTrue(any(item[1] == 'PRIVATE_FILE_IN_ARTIFACT' for item in scanner.findings))

    def test_config_decodes_escaped_secret_and_rejects_extra_server_fields(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'config.json'
            config = {'APP_ENV': 'staging', 'SUPABASE_PROJECT_REF': 'a' * 20,
                      'SUPABASE_URL': 'https://' + 'a' * 20 + '.supabase.co',
                      'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_fixture',
                      'AUTH_RECOVERY_REDIRECT_URL': 'https://app.fixture.invalid/auth/recovery'}
            path.write_text(json.dumps(config), encoding='utf-8')
            scanner = audit.Scanner(); scanner.config(path)
            self.assertFalse(scanner.findings)
            config['SUPABASE_PUBLISHABLE_KEY'] = secret()
            path.write_text(json.dumps(config).replace('sb_', '\\u0073b_'), encoding='utf-8')
            scanner = audit.Scanner(); scanner.config(path)
            self.assertIn('SUPABASE_SECRET', {item[1] for item in scanner.findings})
            config['SUPABASE_PUBLISHABLE_KEY'] = 'sb_publishable_fixture'
            config['SERVER_ONLY_SETTING'] = 'not a client build input'
            path.write_text(json.dumps(config), encoding='utf-8')
            scanner = audit.Scanner(); scanner.config(path)
            self.assertIn('INVALID_CLIENT_RELEASE_CONFIG', {item[1] for item in scanner.findings})

    def test_cli_never_prints_values_or_raw_errors(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'test.json').write_text(json.dumps({'key': secret()}), encoding='utf-8')
            output = io.StringIO()
            with redirect_stdout(output):
                code = audit.main(['--root', folder])
            self.assertEqual(code, 1)
            self.assertNotIn(secret(), output.getvalue())
            self.assertEqual(json.loads(output.getvalue())['status'], 'BLOCKED')
            output = io.StringIO()
            with redirect_stdout(output):
                code = audit.main(['--unknown-' + secret()])
            self.assertEqual(code, 2)
            self.assertNotIn(secret(), output.getvalue())

    def test_release_config_requires_an_exact_https_recovery_destination(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'config.json'
            config = {'APP_ENV': 'staging', 'SUPABASE_PROJECT_REF': 'a' * 20,
                      'SUPABASE_URL': 'https://' + 'a' * 20 + '.supabase.co',
                      'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_fixture'}
            for callback in ['', 'http://localhost:7390/auth/recovery',
                             'smartrental://auth/recovery',
                             'https://app.fixture.invalid/auth/recovery?redirect=other',
                             'https://app.fixture.invalid/']:
                config['AUTH_RECOVERY_REDIRECT_URL'] = callback
                path.write_text(json.dumps(config), encoding='utf-8')
                scanner = audit.Scanner(); scanner.config(path)
                self.assertIn('INVALID_CLIENT_RELEASE_CONFIG', {item[1] for item in scanner.findings})
    def test_history_detects_deleted_secret_in_reachable_local_commits(self):
        with tempfile.TemporaryDirectory() as folder:
            def git(*args):
                return subprocess.run(['git', '-c', 'user.name=Synthetic Fixture',
                    '-c', 'user.email=test@fixture.invalid', *args], cwd=folder,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            git('init')
            path = Path(folder) / 'config.txt'
            path.write_text(secret(), encoding='utf-8'); git('add', 'config.txt'); git('commit', '-m', 'Synthetic fixture')
            path.write_text('removed fixture', encoding='utf-8'); git('commit', '-am', 'Remove fixture')
            scanner = audit.Scanner(); scanner.worktree(Path(folder))
            self.assertFalse(scanner.findings)
            scanner.history(Path(folder))
            self.assertTrue(any(item[1] == 'SUPABASE_SECRET' for item in scanner.findings))

    def test_source_guard_rejects_new_raw_log_sinks_and_error_interpolation(self):
        with tempfile.TemporaryDirectory() as folder:
            library = Path(folder) / 'lib'; library.mkdir()
            (library / 'bad.dart').write_text("debugPrint('private $error');", encoding='utf-8')
            scanner = audit.Scanner(); scanner.worktree(Path(folder))
            self.assertEqual({item[1] for item in scanner.findings}, {'UNSAFE_LOG_SINK', 'RAW_ERROR_INTERPOLATION'})

    def test_unknown_jwt_shapes_do_not_crash_scanner(self):
        value = 'eyJ0eXAiOiJKV1QifQ.' + base64.urlsafe_b64encode(b'[1,2,3,4,5]').decode().rstrip('=') + '.SYNTHETIC'
        self.assertFalse(list(audit.findings_in_text(value)))


if __name__ == '__main__':
    unittest.main()
