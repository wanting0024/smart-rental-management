"""Local-only, redacted secret-pattern/release-config checks. Standard library only.

Not a universal credential detector or proof that old credentials were revoked.
No file extraction, source mutation, network request or matched value output.
"""
import argparse
import base64
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile
from urllib.parse import urlsplit

MAX_FILE = 256 * 1024 * 1024
MAX_TOTAL = 2 * 1024 * 1024 * 1024
MAX_OBJECTS = 20000
OVERLAP = 32768
SKIP_DIRS = {'.git', '.dart_tool', '.gradle', '.idea', '.pub-cache', 'build',
             'node_modules', 'Pods', '.symlinks', 'ephemeral', '__pycache__'}
TEXT_SUFFIXES = {'.dart', '.html', '.js', '.mjs', '.cjs', '.json', '.yaml', '.yml',
                '.xml', '.plist', '.gradle', '.properties', '.md', '.txt', '.env',
                '.pem', '.key', '.sh', '.ps1', '.xcconfig', '.toml', '.ini', '.cfg',
                '.sql', '.py', '.lock', '.entitlements'}
PATTERNS = (
    ('SUPABASE_SECRET', re.compile(r'sb_secret_[A-Za-z0-9_-]{12,256}')),
    ('STRIPE_SECRET', re.compile(r'(?:sk_(?:live|test)_|whsec_)[A-Za-z0-9]{16,256}')),
    ('GITHUB_TOKEN', re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,256}|github_pat_[A-Za-z0-9_]{40,256})')),
    ('PRIVATE_KEY', re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----\s+[A-Za-z0-9+/=\r\n]{40,8192}-----END (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----')),
    ('REFRESH_TOKEN', re.compile(r'"refresh_token"\s*:\s*"[A-Za-z0-9_-]{16,1024}"')),
)
JWT = re.compile(r'eyJ[A-Za-z0-9_-]{8,512}\.[A-Za-z0-9_-]{8,8192}\.[A-Za-z0-9_-]{8,1024}')
RAW_LOG = re.compile(r'\b(?:debugPrint|print|Logger)\s*\(|\b(?:developer|stdout|stderr)\.(?:log|write|writeln)\s*\(')
RAW_ERROR_UI = re.compile(r'\$(?:error\b|lookupError\b|\{snapshot\.error\})')
PRIVATE_ARTIFACT_SUFFIXES = {'.jks', '.keystore', '.p12', '.pfx', '.mobileprovision'}


class ScanIncomplete(Exception):
    pass


def jwt_payload(value):
    try:
        part = value.split('.')[1]
        payload = json.loads(base64.urlsafe_b64decode(part + '=' * (-len(part) % 4)))
        return payload if isinstance(payload, dict) else {}
    except (ValueError, IndexError, UnicodeError):
        return {}


def findings_in_text(text):
    for rule, pattern in PATTERNS:
        for match in pattern.finditer(text):
            yield rule, text.count('\n', 0, match.start()) + 1
    for match in JWT.finditer(text):
        role = jwt_payload(match.group()).get('role')
        if role in ('service_role', 'authenticated'):
            yield ('SERVICE_ROLE_JWT' if role == 'service_role' else 'USER_SESSION_JWT'), text.count('\n', 0, match.start()) + 1


def safe_path(value):
    # Even a strangely named file must not turn the report into a secret leak.
    return '<sensitive-path>' if any(findings_in_text(value)) else value


class Scanner:
    def __init__(self):
        self.findings = set()
        self.total = 0
        self.files = 0
        self.history_objects = 0

    def add(self, path, rule, line=1):
        self.findings.add((safe_path(str(path)), rule, line))

    def artifact_name(self, name):
        basename = Path(name.replace('\\', '/')).name.lower()
        if (Path(basename).suffix in PRIVATE_ARTIFACT_SUFFIXES or
            basename == 'key.properties' or basename == '.env' or
            (basename.startswith('.env.') and basename != '.env.example') or
            re.fullmatch(r'backend_config.*\.local\.json', basename)):
            self.add(name, 'PRIVATE_FILE_IN_ARTIFACT')

    def stream(self, stream, name):
        self.files += 1
        tail = b''
        consumed = 0
        line_offset = 0
        while True:
            block = stream.read(1024 * 1024)
            if not block:
                break
            consumed += len(block)
            self.total += len(block)
            if consumed > MAX_FILE or self.total > MAX_TOTAL:
                raise ScanIncomplete()
            combined = tail + block
            for index, encoding in ((0, 'utf-8'), (0, 'utf-16le'), (1, 'utf-16le')):
                # Preserve malformed binary boundaries. Dropping invalid bytes
                # can join a harmless prefix literal with an unrelated adjacent
                # symbol in an AOT string pool and invent a credential. Actual
                # contiguous UTF-8/UTF-16 keys still match, including across chunks.
                text = combined[index:].decode(encoding, errors='replace')
                for rule, line in findings_in_text(text):
                    self.add(name, rule, max(1, line_offset + line))
            # Retain enough context for split UTF-16 keys, JWTs and PEM blocks.
            discarded = combined[:-OVERLAP] if len(combined) > OVERLAP else b''
            line_offset += discarded.count(b'\n')
            tail = combined[-OVERLAP:]

    def archive(self, source, name, depth=0):
        if depth > 2:
            raise ScanIncomplete()
        with zipfile.ZipFile(source) as archive:
            entries = archive.infolist()
            if len(entries) > MAX_OBJECTS:
                raise ScanIncomplete()
            for entry in entries:
                if entry.is_dir():
                    continue
                if entry.flag_bits & 1 or entry.file_size > MAX_FILE:
                    raise ScanIncomplete()
                label = f'{name}!{entry.filename}'
                self.artifact_name(label)
                with archive.open(entry) as member:
                    if Path(entry.filename).suffix.lower() in {'.zip', '.apk', '.aab', '.jar'}:
                        # Never extract; bounded nested archives are inspected in memory.
                        if entry.file_size > 32 * 1024 * 1024:
                            raise ScanIncomplete()
                        data = member.read()
                        self.total += len(data)
                        if self.total > MAX_TOTAL:
                            raise ScanIncomplete()
                        self.archive(io.BytesIO(data), label, depth + 1)
                    else:
                        self.stream(member, label)

    def file(self, path, name=None):
        path = Path(path)
        if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_FILE:
            raise ScanIncomplete()
        label = str(name or path)
        if path.suffix.lower() in {'.zip', '.apk', '.aab', '.jar'}:
            self.archive(path, label)
        else:
            with path.open('rb') as stream:
                self.stream(stream, label)

    def worktree(self, root):
        def unreadable(_):
            raise ScanIncomplete()
        for directory, folders, files in os.walk(root, followlinks=False, onerror=unreadable):
            folders[:] = sorted(name for name in folders if name not in SKIP_DIRS)
            if any((Path(directory) / name).is_symlink() for name in folders):
                raise ScanIncomplete()
            for name in sorted(files):
                path = Path(directory) / name
                if path.suffix.lower() not in TEXT_SUFFIXES and not name.startswith('.env'):
                    continue
                relative = path.relative_to(root).as_posix()
                self.file(path, relative)
                if relative.startswith('lib/') and path.suffix == '.dart':
                    source = path.read_text(encoding='utf-8')
                    if relative != 'lib/services/backend/safe_diagnostics.dart' and RAW_LOG.search(source):
                        self.add(relative, 'UNSAFE_LOG_SINK')
                    if RAW_ERROR_UI.search(source):
                        self.add(relative, 'RAW_ERROR_INTERPOLATION')

    def history(self, root):
        result = subprocess.run(['git', 'rev-list', '--objects', '--all'], cwd=root,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=30, check=True)
        objects = result.stdout.decode('utf-8', errors='replace').splitlines()
        if len(objects) > MAX_OBJECTS:
            raise ScanIncomplete()
        process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=root,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            for obj in objects:
                oid, _, path = obj.partition(' ')
                if not re.fullmatch('[a-f0-9]{40,64}', oid):
                    raise ScanIncomplete()
                process.stdin.write((oid + '\n').encode('ascii'))
                process.stdin.flush()
                header = process.stdout.readline().split()
                if len(header) != 3 or not header[2].isdigit():
                    raise ScanIncomplete()
                size = int(header[2])
                if size > MAX_FILE:
                    raise ScanIncomplete()
                data = process.stdout.read(size)
                if len(data) != size or process.stdout.read(1) != b'\n':
                    raise ScanIncomplete()
                self.history_objects += 1
                label = f'git:{oid[:12]}:{path or "<object>"}'
                if Path(path).suffix.lower() in {'.zip', '.apk', '.aab', '.jar'}:
                    self.archive(io.BytesIO(data), label)
                else:
                    self.stream(io.BytesIO(data), label)
        finally:
            process.stdin.close()
            process.stdout.close()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

    def config(self, path):
        self.file(path)
        data = json.loads(Path(path).read_text(encoding='utf-8-sig'))
        allowed = {'APP_ENV', 'SUPABASE_URL', 'SUPABASE_PROJECT_REF',
                   'SUPABASE_PUBLISHABLE_KEY', 'ALLOW_PRODUCTION_BACKEND',
                   'AUTH_RECOVERY_REDIRECT_URL'}
        valid = isinstance(data, dict) and not set(data) - allowed
        if valid:
            for value in data.values():
                if isinstance(value, str):
                    for rule, line in findings_in_text(value):
                        self.add(path, rule, line)
            ref = data.get('SUPABASE_PROJECT_REF', '')
            key = data.get('SUPABASE_PUBLISHABLE_KEY', '')
            env = data.get('APP_ENV')
            production = data.get('ALLOW_PRODUCTION_BACKEND', False)
            callback = urlsplit(data.get('AUTH_RECOVERY_REDIRECT_URL', ''))
            valid = (isinstance(ref, str) and re.fullmatch('[a-z]{20}', ref) and
                     data.get('SUPABASE_URL') in (f'https://{ref}.supabase.co', f'https://{ref}.supabase.co/') and
                     env in ('staging', 'production') and isinstance(key, str) and
                     (re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+', key) or jwt_payload(key).get('role') == 'anon') and
                     callback.scheme == 'https' and callback.hostname and
                     callback.username is None and callback.password is None and
                     callback.port is None and callback.path == '/auth/recovery' and
                     not callback.query and not callback.fragment and
                     type(production) in (bool, str) and
                     (production in (True, 'true') if env == 'production' else production in (False, 'false')))
        if not valid:
            self.add(path, 'INVALID_CLIENT_RELEASE_CONFIG')

    def artifact(self, path):
        path = Path(path)
        if path.is_dir():
            if path.is_symlink():
                raise ScanIncomplete()
            count = 0
            def unreadable(_):
                raise ScanIncomplete()
            for directory, folders, files in os.walk(path, followlinks=False, onerror=unreadable):
                if any((Path(directory) / name).is_symlink() for name in folders):
                    raise ScanIncomplete()
                for name in files:
                    count += 1
                    if count > MAX_OBJECTS:
                        raise ScanIncomplete()
                    file = Path(directory) / name
                    self.artifact_name(file.as_posix())
                    self.file(file, f'{path.name}/{file.relative_to(path).as_posix()}')
            if count == 0:
                raise ScanIncomplete()
        else:
            self.artifact_name(path.as_posix())
            self.file(path)


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise ScanIncomplete()  # Do not echo arbitrary CLI argument values.


def main(argv=None):
    scanner = Scanner()
    try:
        parser = SafeParser(description=__doc__)
        parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
        parser.add_argument('--history', action='store_true')
        parser.add_argument('--config', type=Path)
        parser.add_argument('--artifact', type=Path, action='append', default=[])
        args = parser.parse_args(argv)
        root = args.root.resolve(strict=True)
        if not root.is_dir():
            raise ScanIncomplete()
        scanner.worktree(root)
        if args.history:
            scanner.history(root)
        if args.config:
            scanner.config(args.config)
        for artifact in args.artifact:
            scanner.artifact(artifact)
        status = 'BLOCKED' if scanner.findings else 'PASS'
        code = 1 if scanner.findings else 0
    except Exception:
        status, code = 'INCOMPLETE', 2
    print(json.dumps({'status': status, 'files': scanner.files,
                      'history_objects': scanner.history_objects,
                      'findings': [{'path': path, 'rule': rule, 'line': line}
                                   for path, rule, line in sorted(scanner.findings)],
                      'matched_values': 'NEVER_OUTPUT'}, ensure_ascii=True))
    return code


if __name__ == '__main__':
    sys.exit(main())
