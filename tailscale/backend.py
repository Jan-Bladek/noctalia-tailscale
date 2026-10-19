#!/usr/bin/env python3
"""Small JSON bridge. Never invokes a shell or elevates privileges."""
import ipaddress
import json
import subprocess
import sys
from urllib.parse import urlsplit


def run(*args, timeout=8):
    return subprocess.run(['tailscale', *args], capture_output=True, text=True, timeout=timeout)


def read_json(*args):
    result = run(*args)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout)


def safe_url(value):
    parsed = urlsplit(value)
    return value if parsed.scheme == 'https' and parsed.hostname and not parsed.username else ''


def snapshot():
    status = read_json('status', '--json')
    prefs, pref_error = {}, ''
    try:
        prefs = read_json('debug', 'prefs')
    except (RuntimeError, ValueError) as exc:
        pref_error = str(exc)
    peers = list((status.get('Peer') or {}).values())
    routes = prefs.get('AdvertiseRoutes') or []
    exits = []
    for peer in peers:
        ips = peer.get('TailscaleIPs') or []
        if peer.get('ExitNodeOption') and ips:
            exits.append({'id': peer.get('ID', ''), 'ip': ips[0],
                          'name': peer.get('DNSName', '').split('.')[0] or peer.get('HostName', 'Unknown'),
                          'online': bool(peer.get('Online')), 'selected': bool(peer.get('ExitNode'))})
    return {'state': status.get('BackendState', 'Unknown'),
            'hostname': (status.get('Self') or {}).get('HostName', ''),
            'ips': status.get('TailscaleIPs') or [],
            'authUrl': safe_url(status.get('AuthURL') or ''),
            'exits': sorted(exits, key=lambda p: p['name'].lower()),
            'health': status.get('Health') or [], 'prefsError': pref_error,
            'acceptRoutes': prefs.get('RouteAll', False), 'acceptDns': prefs.get('CorpDNS', True),
            'allowLan': prefs.get('ExitNodeAllowLANAccess', False),
            'shieldsUp': prefs.get('ShieldsUp', False),
            'advertiseExit': '0.0.0.0/0' in routes and '::/0' in routes,
            'routes': ','.join(r for r in routes if r not in ('0.0.0.0/0', '::/0'))}


FLAGS = {'acceptRoutes': 'accept-routes', 'acceptDns': 'accept-dns',
         'allowLan': 'exit-node-allow-lan-access', 'shieldsUp': 'shields-up',
         'advertiseExit': 'advertise-exit-node'}


def action_args(action, value=''):
    if action == 'connect':
        return ['up']
    if action == 'disconnect':
        return ['down']
    if action in FLAGS:
        if value not in ('true', 'false'):
            raise ValueError('Expected true or false')
        return ['set', '--' + FLAGS[action] + '=' + value]
    if action == 'exit':
        if value:
            value = str(ipaddress.ip_address(value))
        return ['set', '--exit-node=' + value]
    if action == 'routes':
        nets = [ipaddress.ip_network(r.strip(), strict=True) for r in value.split(',') if r.strip()]
        if any(n.prefixlen == 0 for n in nets):
            raise ValueError('Use the advertise exit node switch for default routes')
        return ['set', '--advertise-routes=' + ','.join(map(str, nets))]
    raise ValueError('Unknown action')


def execute(action, value=''):
    if action == 'status':
        return snapshot()
    if action in ('login', 'connect'):
        # ANY CLI flag (even --timeout) activates up's preference-reset checks.
        # Bound the child in Python, preserving all daemon preferences.
        timed_out = False
        try:
            result = run('up', timeout=8)
        except subprocess.TimeoutExpired:
            timed_out = True
            result = None
        status = snapshot()
        if status['authUrl'] or status['state'] == 'Running':
            return {'ok': True, 'authUrl': status['authUrl']}
        if timed_out:
            raise RuntimeError('Connection is still starting. Check daemon health and retry.')
    else:
        result = run(*action_args(action, value))
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Tailscale command failed')
    return {'ok': True}


if __name__ == '__main__':
    try:
        print(json.dumps(execute(*sys.argv[1:])))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({'error': str(exc)}))
        sys.exit(1)
