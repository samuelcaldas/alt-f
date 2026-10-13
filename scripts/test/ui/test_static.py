"""Production inventory, syntax and legacy form-contract checks."""
import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path
from shell_renderer import CGI_ROOT, WEB_ROOT


def form_contract(source):
    """Extract unchanged form targets and submitted field names/values."""
    tags = re.findall(r'<(?:form|input|select|textarea)\b[^>]*>', source, re.I)
    attributes = r'\b(action|method|enctype|name|value)\s*=\s*("[^"]*"|\'[^\']*\'|[^\s>]+)'
    return [re.findall(attributes, tag, re.I) for tag in tags]


class SourceContractTests(unittest.TestCase):
    def test_no_navigation_frame_dependencies(self):
        files = list(CGI_ROOT.glob('*.cgi')) + list(WEB_ROOT.glob('scripts/**/*.js'))
        files += [WEB_ROOT / 'index.html', CGI_ROOT / 'common.sh']
        pattern = r'<frameset\b|parent\.(?:frames|nav|content)|top\.altf|target=["\']content'
        violations = [str(path) for path in files if re.search(pattern, path.read_text())]
        self.assertEqual(violations, [])

    def test_legacy_submitted_fields_are_unchanged(self):
        expected = json.loads(Path('/tests/fixtures/form_contracts.json').read_text())
        for filename, contract in expected.items():
            with self.subTest(page=filename):
                actual = form_contract((CGI_ROOT / filename).read_text())
                self.assertEqual(json.loads(json.dumps(actual)), contract)

    def test_known_baseline_is_unchanged(self):
        issues = json.loads(Path('/tests/fixtures/baseline_issues.json').read_text())
        for filename, issue in issues.items():
            self.assertEqual(hashlib.sha256((CGI_ROOT / filename).read_bytes()).hexdigest(), issue['sha256'])
            print('KNOWN BASELINE:', filename, issue['reason'])

    def test_scripts_parse_under_busybox_ash(self):
        issues = json.loads(Path('/tests/fixtures/baseline_issues.json').read_text())
        paths = list(CGI_ROOT.glob('*.cgi')) + list(CGI_ROOT.glob('*.sh'))
        paths = [path for path in paths if path.name not in issues]
        for path in paths:
            with self.subTest(page=path.name):
                result = subprocess.run(['/bin/busybox', 'ash', '-n', str(path)], capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr.decode())

    def test_theme_assets_are_in_firmware_inventory(self):
        inventory = Path('/source/rootfsfiles-base.lst').read_text().splitlines()
        for directory in ['scripts/ui', 'scripts/classic']:
            for path in (WEB_ROOT / directory).rglob('*'):
                with self.subTest(asset=path.name):
                    relative = './usr/www/' + str(path.relative_to(WEB_ROOT))
                    self.assertIn(relative, inventory)
        for name in ['ui_shell.sh', 'ui_navigation.sh', 'ui_menu.awk']:
            self.assertIn('./usr/www/cgi-bin/' + name, inventory)
        self.assertIn('./usr/www/scripts/classic.thm', inventory)

    def test_html_pages_use_shared_footer(self):
        violations = []
        for path in CGI_ROOT.glob('*.cgi'):
            if path.is_symlink():
                continue
            source = path.read_text()
            if re.search(r'</body>\s*</html>', source, re.I):
                violations.append(path.name)
        self.assertEqual(violations, [])

    def test_status_access_and_refresh_intervals_unchanged(self):
        source = (CGI_ROOT / 'status.cgi').read_text()
        self.assertNotIn('check_cookie', source)
        values = re.findall(r"requestfromserver\('[^']+', (\d+)\)", source)
        self.assertEqual(values, ['11', '11', '13', '13', '17', '17', '19', '19', '23', '23', '31', '59'])

    def test_help_pages_have_mobile_viewport(self):
        for path in WEB_ROOT.glob('*_hlp.html'):
            with self.subTest(page=path.name):
                self.assertIn('name="viewport"', path.read_text())


if __name__ == '__main__':
    unittest.main()
