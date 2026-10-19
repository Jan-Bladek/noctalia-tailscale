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
