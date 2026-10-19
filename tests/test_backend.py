import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('backend', Path(__file__).parents[1] / 'tailscale/backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class BackendTests(unittest.TestCase):
    def test_preferences_are_set_individually(self):
        self.assertEqual(b.action_args('acceptRoutes', 'true'), ['set', '--accept-routes=true'])
        self.assertEqual(b.action_args('connect'), ['up'])
        self.assertEqual(b.action_args('disconnect'), ['down'])
        self.assertEqual(b.action_args('exit', ''), ['set', '--exit-node='])

    def test_injection_and_invalid_flags_rejected(self):
        for action, value in [('exit', '1.2.3.4; touch /tmp/oops'), ('acceptDns', 'yes'),
                              ('routes', '192.168.1.1/24'), ('routes', '0.0.0.0/0'),
                              ('routes', '$(whoami)'), ('logout', '')]:
            with self.subTest(action=action, value=value), self.assertRaises(ValueError):
                b.action_args(action, value)

    def test_ipv4_ipv6_routes_and_clearing(self):
        self.assertEqual(b.action_args('routes', '10.0.0.0/24, fd00::/64'),
                         ['set', '--advertise-routes=10.0.0.0/24,fd00::/64'])
        self.assertEqual(b.action_args('routes', ''), ['set', '--advertise-routes='])

    def test_snapshot_filters_exit_nodes_and_default_routes(self):
        status = {'BackendState': 'Running', 'Peer': {
            'a': {'ID': 'a', 'ExitNodeOption': True, 'Online': True, 'ExitNode': True,
                  'HostName': 'gateway', 'TailscaleIPs': ['100.64.0.1']},
            'b': {'HostName': 'ordinary', 'TailscaleIPs': ['100.64.0.2']}}, 'AuthURL': 'file:///etc/passwd'}
        prefs = {'RouteAll': True, 'AdvertiseRoutes': ['0.0.0.0/0', '::/0', '10.0.0.0/24']}
        with patch.object(b, 'read_json', side_effect=[status, prefs]):
            data = b.snapshot()
        self.assertEqual(len(data['exits']), 1)
        self.assertTrue(data['exits'][0]['selected'])
        self.assertTrue(data['advertiseExit'])
        self.assertTrue(data['acceptRoutes'])
        self.assertEqual(data['routes'], '10.0.0.0/24')
        self.assertEqual(data['authUrl'], '')

    def test_prefs_permission_failure_still_returns_status(self):
        with patch.object(b, 'read_json', side_effect=[{'BackendState': 'Stopped'}, RuntimeError('permission denied')]):
            data = b.snapshot()
        self.assertEqual(data['state'], 'Stopped')
        self.assertEqual(data['prefsError'], 'permission denied')

    def test_login_timeout_with_auth_url_is_success(self):
        with patch.object(b, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'timeout')), \
             patch.object(b, 'snapshot', return_value={'authUrl': 'https://login.tailscale.com/a/test', 'state': 'NeedsLogin'}):
            self.assertTrue(b.execute('login')['ok'])

    def test_login_python_timeout_still_returns_daemon_url(self):
        with patch.object(b, 'run', side_effect=subprocess.TimeoutExpired(['tailscale', 'up'], 8)), \
             patch.object(b, 'snapshot', return_value={'authUrl': 'https://login.tailscale.com/a/test', 'state': 'NeedsLogin'}):
            self.assertTrue(b.execute('connect')['ok'])

    def test_connect_preserves_existing_preferences(self):
        with patch.object(b, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')) as run, \
             patch.object(b, 'snapshot', return_value={'authUrl': '', 'state': 'Running'}):
            self.assertTrue(b.execute('connect')['ok'])
        run.assert_called_once_with('up', timeout=8)

    def test_run_passes_arguments_without_shell(self):
        with patch.object(b.subprocess, 'run') as run:
            b.run('set', '--exit-node=')
        self.assertEqual(run.call_args.args[0], ['tailscale', 'set', '--exit-node='])
        self.assertNotIn('shell', run.call_args.kwargs)

    def test_urls_require_https_without_userinfo(self):
        for value in ['javascript:alert(1)', 'https://user@example.com/a', '//example.com/a', 'http://example.com']:
            self.assertEqual(b.safe_url(value), '')
        self.assertEqual(b.safe_url('https://login.tailscale.com/a/test'), 'https://login.tailscale.com/a/test')


if __name__ == '__main__':
    unittest.main()
