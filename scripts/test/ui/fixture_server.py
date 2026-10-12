"""Generate reviewed helper fixtures and expose them with BusyBox httpd.

Original service CGI files stay non-executable. These fixtures test real shared
presentation with synthetic bodies, not execution of the administrative pages.
"""
import json
import subprocess
from pathlib import Path
from shell_renderer import CGI_ROOT, WEB_ROOT, render_shell

TEST_ROOT = Path('/tmp/ui-web')


def fixture_script(script):
    """Create an allowlisted test CGI from synthetic body and real helpers."""
    script.write_text('''#!/bin/busybox ash
cd /usr/www/cgi-bin || exit 1
. ./common.sh
loadsave_settings() { return 0; }
read_args
write_header "Fixture result"
printf '<p id="submitted">%s</p>' "$submit"
write_footer
''')
    script.chmod(0o755)


def page_fixture(path):
    """Capture shared UI with table/form widgets and route-specific identity."""
    return f'''<fieldset><legend>{path.stem}</legend>
<form action="/cgi-bin/fixture_submit.cgi" method="post">
<table><tr><td><label for="workgp">Workgroup</label></td>
<td><input id="workgp" name="workgp" value="WORKGROUP"></td></tr></table>
<input type="submit" name="submit" value="Submit"></form></fieldset>
<div class="table-scroll" role="region" tabindex="0" aria-label="Shares"><table class="data-table">
<tr><th>Name</th><th>Folder</th><th>User</th><th>Group</th><th>Access</th><th>Guest</th><th>Comment</th><th>Status</th><th>Action</th></tr>
<tr><td>Photos</td><td>/mnt/Volume_1/very-long-folder-name</td><td>user</td><td>group</td><td>Read/write</td><td>No</td><td>Long sample comment</td><td>Ready</td><td>Edit</td></tr></table></div>
<form action="/cgi-bin/fixture_upload.cgi" method="post" enctype="multipart/form-data">
<label for="upload">Settings file</label><input id="upload" type="file" name="upload">
<input type="submit" value="Upload"></form>
<a href="/cgi-bin/fixture_download.cgi">Download fixture</a>'''


def render_fixture(path):
    """Render only shared presentation; original CGI handlers are never run."""
    body = page_fixture(path)
    import os
    environment = os.environ.copy()
    environment.update(TEST_TITLE=path.stem, TEST_BODY=body)
    commands = '. ./common.sh; loadsave_settings() { return 0; }; write_header "$TEST_TITLE"; printf "%s" "$TEST_BODY"; write_footer'
    return subprocess.check_output(['/bin/busybox', 'ash', '-c', commands, '/cgi-bin/' + path.name],
                                   cwd=CGI_ROOT, env=environment, text=True)


def create_fixtures():
    """Expose local assets and capture every renderable route as an explicit mock."""
    TEST_ROOT.mkdir(exist_ok=True)
    (TEST_ROOT / 'cgi-bin').mkdir(exist_ok=True)
    (TEST_ROOT / 'pages').mkdir(exist_ok=True)
    (TEST_ROOT / 'scripts').symlink_to(WEB_ROOT / 'scripts', target_is_directory=True)
    coverage = []
    for path in CGI_ROOT.glob('*.cgi'):
        source = path.read_text()
        if 'write_header' not in source and 'html_header' not in source:
            coverage.append({'route': path.name, 'mode': 'integration not executed: handler/alias/embed'})
            continue
        response = render_fixture(path)
        body = response.partition('\n\n')[2]
        (TEST_ROOT / 'pages' / (path.name + '.html')).write_text(body)
        route = TEST_ROOT / 'cgi-bin' / path.name
        route.write_text('#!/bin/busybox ash\nprintf "Content-Type: text/html\\r\\n\\r\\n"\ncat /tmp/ui-web/pages/' + path.name + '.html\n')
        route.chmod(0o755)
        coverage.append({'route': path.name, 'mode': 'shared-shell fixture; original page logic NOT executed'})
    Path('/tmp/ui-coverage.json').write_text(json.dumps(coverage, indent=2))
    fixture_script(TEST_ROOT / 'cgi-bin/fixture_submit.cgi')
    embed = render_shell('embed_page "/pages/smb.cgi.html" "Embedded service"')
    (TEST_ROOT / 'pages/embed-example.html').write_text(embed.partition('\n\n')[2])
    create_special_endpoints()


def create_special_endpoints():
    """Development-only multipart and download fixtures; do not mutate NAS settings."""
    upload = TEST_ROOT / 'cgi-bin/fixture_upload.cgi'
    upload.write_text('''#!/bin/busybox ash
payload=$(cat)
printf 'Content-Type: text/plain\\r\\n\\r\\n'
printf '%s' "$payload"
''')
    upload.chmod(0o755)
    download = TEST_ROOT / 'cgi-bin/fixture_download.cgi'
    download.write_text('''#!/bin/busybox ash
cd /usr/www/cgi-bin || exit 1
. ./common.sh
printf 'test download' > /tmp/ui-fixture-download
download_file /tmp/ui-fixture-download settings.txt
''')
    download.chmod(0o755)


if __name__ == '__main__':
    create_fixtures()
    subprocess.run(['/bin/busybox', 'httpd', '-f', '-p', '8080', '-h', str(TEST_ROOT)], check=True)
