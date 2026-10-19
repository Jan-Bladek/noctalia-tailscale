"""Exercise the installer in dry-run mode against os-release fixtures."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


@unittest.skipIf(os.geteuid() == 0, 'Installer must run as the desktop user')
class InstallerTests(unittest.TestCase):
    def check_distro(self, release, expected, code=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = root / 'os-release'
            fixture.write_text(release)
            script = root / 'install.sh'
            source = Path(__file__).parents[1] / 'install.sh'
            script.write_text(source.read_text().replace('/etc/os-release', str(fixture)))
            result = subprocess.run(['bash', str(script), '--setup-system', '--dry-run'],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, code, result.stderr)
            self.assertIn(expected, result.stdout + result.stderr)

    def test_omarchy(self):
        self.check_distro('ID=omarchy\nID_LIKE=arch\n', 'sudo pacman -Syu')

    def test_arch_derivative(self):
        self.check_distro('ID=custom\nID_LIKE="other arch"\n', 'sudo pacman -Syu')

    def test_fedora(self):
        self.check_distro('ID=fedora\n', 'sudo dnf install')

    def test_fedora_derivative(self):
        self.check_distro("ID=custom\nID_LIKE='fedora rhel'\n", 'sudo dnf install')

    def test_unsupported(self):
        self.check_distro('ID=debian\n', 'Unsupported distribution: debian', 1)

    def test_upgrade_backs_up_outside_plugin_discovery(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = root / 'data'
            state = root / 'state'
            (data / 'noctalia/plugins/tailscale').mkdir(parents=True)
            env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_STATE_HOME=str(state))
            result = subprocess.run(['bash', str(Path(__file__).parents[1] / 'install.sh'), '--plugin-only', '--dry-run'],
                                    text=True, capture_output=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(state / 'noctalia/plugin-backups/tailscale.'), result.stdout)
            self.assertNotIn(str(data / 'noctalia/plugins/tailscale.backup'), result.stdout)
            self.assertLess(result.stdout.index('/tailscale/icons.luau'), result.stdout.index('/tailscale/widget.luau'))

    def test_legacy_backups_are_moved_out_of_discovery(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = root / 'data'
            state = root / 'state'
            legacy = data / 'noctalia/plugins/tailscale.backup.123'
            legacy.mkdir(parents=True)
            (legacy / 'plugin.toml').write_text('id = "Jan-Bladek/tailscale"')
            result = subprocess.run(['bash', str(Path(__file__).parents[1] / 'install.sh'), '--plugin-only', '--dry-run'],
                                    text=True, capture_output=True,
                                    env=dict(os.environ, XDG_DATA_HOME=str(data), XDG_STATE_HOME=str(state)))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('mv -- ' + str(legacy), result.stdout)
            self.assertIn(str(state / 'noctalia/plugin-backups/tailscale.backup.123.migrated.'), result.stdout)


@unittest.skipIf(os.geteuid() == 0, 'Installer must run as the desktop user')
class InstallerIntegrationTests(unittest.TestCase):
    """Run real file copying while substituting all privileged/network commands."""
    def setUp(self):
        import shutil
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'source with spaces'
        self.project.mkdir()
        source = Path(__file__).parents[1]
        shutil.copytree(source / 'tailscale', self.project / 'tailscale', ignore=shutil.ignore_patterns('__pycache__'))
        self.release = self.root / 'os-release'
        self.release.write_text('ID=arch\n')
        self.repo = self.root / 'tailscale.repo'
        self.script = self.project / 'install.sh'
        self.script.write_text((source / 'install.sh').read_text()
                               .replace('/etc/os-release', str(self.release))
                               .replace('/etc/yum.repos.d/tailscale.repo', str(self.repo)))
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        stub = '''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['INSTALL_TEST_LOG'], 'a') as f:
    f.write(json.dumps([name, *args]) + '\\n')
if name == 'sudo':
    sys.exit(subprocess.run(args).returncode)
elif name == 'id':
    print(os.environ['INSTALL_TEST_USER'])
elif name == 'tailscale' and args == ['debug', 'prefs']:
    print(json.dumps({'OperatorUser': os.environ.get('INSTALL_TEST_OPERATOR', '')}))
elif name == 'curl':
    pathlib.Path(args[args.index('-o') + 1]).write_text('[tailscale-stable]\\n')
elif name == 'noctalia':
    print('noctalia v5.3.0')
'''
        for command in ('sudo', 'pacman', 'dnf', 'systemctl', 'tailscale', 'curl', 'id', 'noctalia', 'xdg-open'):
            path = self.bin / command
            path.write_text(stub)
            path.chmod(0o755)
        self.home = self.root / 'alice home'
        self.home.mkdir()
        self.log = self.root / 'commands.jsonl'
        self.env = dict(os.environ, PATH=str(self.bin) + ':/usr/bin:/bin', HOME=str(self.home),
                        USER='wrong-environment-user', LOGNAME='wrong-environment-user',
                        INSTALL_TEST_USER='alice', INSTALL_TEST_LOG=str(self.log), INSTALL_TEST_OPERATOR='')
        for key in ('XDG_DATA_HOME', 'XDG_STATE_HOME', 'NOCTALIA_DATA_HOME', 'NOCTALIA_STATE_HOME'):
            self.env.pop(key, None)

    def run_install(self, *args):
        return subprocess.run(['bash', str(self.script), *args], text=True, capture_output=True, env=self.env)

    def commands(self):
        import json
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_arch_installs_for_real_user_instead_of_user_environment(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['tailscale', 'set', '--operator=alice'], self.commands())
        installed = self.home / '.local/share/noctalia/plugins/tailscale'
        self.assertEqual((installed / 'backend.py').read_bytes(), (self.project / 'tailscale/backend.py').read_bytes())
        self.assertTrue((installed / 'icons.luau').is_file())

    def test_fedora_downloads_repo_and_uses_dnf(self):
        self.release.write_text('ID=fedora\n')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.repo.read_text(), '[tailscale-stable]\n')
        self.assertIn(['dnf', 'install', '-y', 'tailscale', 'python3', 'xdg-utils'], self.commands())
        self.assertFalse(any(c[0] == 'pacman' for c in self.commands()))

    def test_fedora_reuses_existing_repo(self):
        self.release.write_text('ID=fedora\n')
        self.repo.write_text('existing repo')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.repo.read_text(), 'existing repo')
        self.assertFalse(any(c[0] == 'curl' for c in self.commands()))

    def test_plugin_only_respects_noctalia_paths_and_uses_no_sudo(self):
        data = self.root / 'custom data'
        state = self.root / 'custom state'
        self.env.update(NOCTALIA_DATA_HOME=str(data), NOCTALIA_STATE_HOME=str(state),
                        XDG_DATA_HOME=str(self.root / 'ignored-xdg'))
        for _ in range(2):
            result = self.run_install('--plugin-only')
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((data / 'noctalia/plugins/tailscale/plugin.toml').is_file())
        self.assertTrue(list((state / 'noctalia/plugin-backups').glob('tailscale.*')))
        self.assertFalse(any(c[0] == 'sudo' for c in self.commands()))

    def test_existing_operator_is_not_replaced_silently(self):
        self.env['INSTALL_TEST_OPERATOR'] = 'bob'
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already managed by 'bob'", result.stderr)
        self.assertNotIn(['tailscale', 'set', '--operator=alice'], self.commands())

    def test_explicit_operator_replacement(self):
        self.env['INSTALL_TEST_OPERATOR'] = 'bob'
        result = self.run_install('--replace-operator')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['tailscale', 'set', '--operator=alice'], self.commands())

    def test_skip_operator(self):
        self.env['INSTALL_TEST_OPERATOR'] = 'bob'
        result = self.run_install('--skip-operator')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(c[:2] == ['tailscale', 'set'] for c in self.commands()))

    def test_relative_user_paths_fail_before_system_changes(self):
        self.env['XDG_DATA_HOME'] = 'relative/path'
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must be absolute', result.stderr)
        self.assertFalse(self.log.exists())
