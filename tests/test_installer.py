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
            result = subprocess.run(['bash', str(Path(__file__).parents[1] / 'install.sh'), '--dry-run'],
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
            result = subprocess.run(['bash', str(Path(__file__).parents[1] / 'install.sh'), '--dry-run'],
                                    text=True, capture_output=True,
                                    env=dict(os.environ, XDG_DATA_HOME=str(data), XDG_STATE_HOME=str(state)))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('mv -- ' + str(legacy), result.stdout)
            self.assertIn(str(state / 'noctalia/plugin-backups/tailscale.backup.123.migrated.'), result.stdout)
