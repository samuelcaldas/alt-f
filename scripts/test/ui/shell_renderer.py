"""Render the production shell with synthetic system state, never arbitrary CGI."""
import os
import subprocess
from pathlib import Path

WEB_ROOT = Path('/usr/www')
CGI_ROOT = WEB_ROOT / 'cgi-bin'


def render_shell(commands, script='/cgi-bin/smb.cgi', environment=None):
    """Run reviewed shared helpers under BusyBox ash with development-only stubs."""
    variables = os.environ.copy()
    variables.update({'HTTP_COOKIE': '', 'REQUEST_URI': script, 'REMOTE_ADDR': '127.0.0.1'})
    variables.update(environment or {})
    preparation = ('write_footer() { printf "</body></html>"; }; '
                   '. ./common.sh; loadsave_settings() { return 0; }; ')
    result = subprocess.run(['/bin/busybox', 'ash', '-c', preparation + commands, script],
                            cwd=CGI_ROOT, env=variables, capture_output=True, text=True, check=True)
    return result.stdout


def render_page(title='Samba Setup', body='<p>Fixture content</p>', script='/cgi-bin/smb.cgi'):
    """Render actual headers/navigation around an explicitly synthetic page body."""
    environment = {'TEST_TITLE': title, 'TEST_BODY': body}
    commands = 'write_header "$TEST_TITLE"; printf "%s" "$TEST_BODY"; write_footer'
    return render_shell(commands, script, environment)
