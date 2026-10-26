"""Gate orchestration tests with an isolated synthetic repo/fake compiler only."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(shutil.which('powershell') or shutil.which('pwsh'), 'PowerShell unavailable')
class GateTests(unittest.TestCase):
    def run_gate(self, mode):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder); root = base / 'app'; tools = root / 'tool'; tools.mkdir(parents=True)
            original = Path(__file__).resolve().parent
            for name in ('secure_build.ps1', 'security_scan.py'):
                shutil.copyfile(original / name, tools / name)
            def git(*args):
                subprocess.run(['git', '-c', 'user.name=Synthetic Fixture',
                    '-c', 'user.email=test@fixture.invalid', *args], cwd=root,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            (root / 'README.md').write_text('Synthetic build gate fixture', encoding='utf-8')
            git('init'); git('add', '.'); git('commit', '-m', 'Synthetic fixture')
            config = base / 'config.json'
            key = 'sb_' + 'secret_' + 'SYNTHETIC' * 5
            config.write_text(json.dumps({'APP_ENV':'staging','SUPABASE_PROJECT_REF':'a'*20,
                'SUPABASE_URL':'https://'+'a'*20+'.supabase.co',
                'SUPABASE_PUBLISHABLE_KEY':key if mode=='bad_config' else 'sb_publishable_fixture',
                'AUTH_RECOVERY_REDIRECT_URL':'https://app.fixture.invalid/auth/recovery'}),encoding='utf-8')
            stub = base / 'compiler.py'
            stub.write_text("from pathlib import Path\nimport os,sys\n"
                "print('sb_'+'secret_'+'SYNTHETIC'*5)\n"
                "Path('build/web').mkdir(parents=True,exist_ok=True)\n"
                "Path('build/web/main.dart.js').write_text(('sb_'+'secret_'+'SYNTHETIC'*5) "
                "if os.environ.get('SYNTHETIC_GATE_MODE')=='bad_artifact' else 'safe synthetic artifact')\n"
                "sys.exit(7 if os.environ.get('SYNTHETIC_GATE_MODE')=='build_failure' else 0)\n",encoding='utf-8')
            command = base / 'compiler.cmd'
            command.write_text('@"'+sys.executable+'" "'+str(stub)+'" %*\n',encoding='utf-8')
            env = dict(os.environ, SYNTHETIC_GATE_MODE=mode)
            result = subprocess.run([shutil.which('pwsh') or shutil.which('powershell'),
                '-NoProfile','-File',str(tools/'secure_build.ps1'),'-Target','web',
                '-ConfigPath',str(config),'-FlutterExecutable',str(command),
                '-PythonExecutable',sys.executable],cwd=root,env=env,
                stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60)
            output = result.stdout.decode(errors='replace')+result.stderr.decode(errors='replace')
            self.assertNotIn(key, output)
            return result.returncode, output

    def test_clean_release_orchestration_passes_without_printing_compiler_output(self):
        code, output = self.run_gate('clean')
        self.assertEqual(code,0); self.assertIn('Local release gate passed',output)

    def test_private_config_blocks_before_compiler(self):
        code, output = self.run_gate('bad_config')
        self.assertNotEqual(code,0); self.assertIn('1/3:',output); self.assertNotIn('2/3:',output)

    def test_packaged_secret_or_compiler_failure_blocks_release(self):
        for mode in ('bad_artifact','build_failure'):
            code, output = self.run_gate(mode)
            self.assertNotEqual(code,0); self.assertIn('2/3:',output); self.assertNotIn('Local release gate passed',output)


if __name__ == '__main__':
    unittest.main()
