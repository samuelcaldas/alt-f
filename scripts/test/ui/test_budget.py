"""Bound the NAS UI assets; development tooling is deliberately excluded."""
import re
import unittest
from shell_renderer import CGI_ROOT, WEB_ROOT


def inline_payload_size(source):
    """Measure the inline production payload rather than just external assets."""
    blocks = re.findall(r'<(script|style)[^>]*>(.*?)</\1>', source, re.S | re.I)
    styles = re.findall(r'''LOCAL_STYLE\s*=\s*(['"])(.*?)\1''', source, re.S)
    return sum(len(part.encode()) for _, part in blocks + styles)


class AssetBudgetTests(unittest.TestCase):
    def test_inline_css_counts_toward_budget(self):
        css = 'x' * (100 * 1024 + 1)
        self.assertGreaterEqual(inline_payload_size('<style>' + css + '</style>'), len(css))

    def test_assigned_local_style_counts_toward_budget(self):
        css = 'x' * (100 * 1024 + 1)
        self.assertGreaterEqual(inline_payload_size("LOCAL_STYLE='" + css + "'"), len(css))

    def test_default_ui_is_below_100_kib(self):
        paths = list((WEB_ROOT / 'scripts/ui').glob('*'))
        paths.append(WEB_ROOT / 'scripts/dull/dull.css')
        shared = sum(path.stat().st_size for path in paths)
        common = (CGI_ROOT / 'common.sh').read_text()
        common_scripts = inline_payload_size(common)
        for page in CGI_ROOT.glob('*.cgi'):
            total = shared + common_scripts + inline_payload_size(page.read_text())
            with self.subTest(page=page.name, raw_bytes=total):
                self.assertLessEqual(total, 100 * 1024)

    def test_shared_assets_do_not_load_external_dependencies(self):
        for path in (WEB_ROOT / 'scripts/ui').glob('*'):
            with self.subTest(asset=path.name):
                self.assertNotRegex(path.read_text(), r'https?://|@import')


if __name__ == '__main__':
    unittest.main()
