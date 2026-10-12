"""Behavior checks for real shared CGI helpers, with no NAS services executed."""
import re
import unittest
from pathlib import Path
from shell_renderer import render_page, render_shell


class ShellRenderingTests(unittest.TestCase):
    def test_full_page_has_one_accessible_shell(self):
        document = render_page()
        self.assertIn('<!DOCTYPE html>', document)
        self.assertIn('name="viewport"', document)
        self.assertIn('<main', document)
        self.assertIn('id="main-content"', document)
        self.assertIn('<nav', document)
        self.assertEqual(len(re.findall(r'<main\b', document)), 1)
        self.assertEqual(document.count('</main>'), 1)

    def test_navigation_is_not_a_frame_target(self):
        document = render_page()
        self.assertIn('/cgi-bin/logout.cgi', document)
        self.assertIn('net_services.cgi', document)
        self.assertNotIn('target="content"', document)
        self.assertNotIn('menuSetup(', document)

    def test_header_escapes_titles(self):
        document = render_page('NAS <one> & "two"')
        self.assertIn('NAS &lt;one&gt; &amp;', document)
        self.assertNotIn('<one>', document)

    def test_minimal_header_has_no_administrative_menu(self):
        document = render_shell('html_header; printf "wait"; write_footer')
        self.assertIn('wait', document)
        self.assertNotIn('<nav', document)
        self.assertEqual(document.count('</html>'), 1)

    def test_redirect_has_no_page_wrapper(self):
        response = render_shell('gotopage /cgi-bin/smb.cgi', script='/cgi-bin/smb_proc.cgi')
        self.assertIn('Location: /cgi-bin/smb.cgi', response)
        self.assertNotIn('<html', response)

    def test_expired_session_redirects_without_frames(self):
        response = render_shell('check_cookie', environment={'REQUEST_URI': '/cgi-bin/smb.cgi?a=1&b=two'})
        self.assertIn('Location: /cgi-bin/login.cgi?', response)
        self.assertIn('%26', response)
        self.assertNotIn('<script', response)
        self.assertNotIn('parent.frames', response)

    def test_download_is_not_wrapped(self):
        fixture = Path('/tmp/ui-download.txt')
        fixture.write_text('sample download')
        response = render_shell('download_file /tmp/ui-download.txt example.txt')
        self.assertIn('Content-Disposition: attachment; filename="example.txt"', response)
        self.assertTrue(response.endswith('sample download'))
        self.assertNotIn('<main', response)

    def test_explicit_embed_is_retained(self):
        response = render_shell('embed_page "http://127.0.0.1:9000/" "Service"')
        self.assertIn('<iframe', response)

    def test_header_onload_contract_survives(self):
        response = render_shell('write_header "Example" "initialize()"; write_footer')
        self.assertRegex(response, r'on[lL]oad="initialize\(\)"')

    def test_both_enabled_menus_remain_available(self):
        response = render_shell('TOP_MENU=yes; SIDE_MENU=yes; write_header "Example"; write_footer')
        self.assertEqual(response.count('<nav'), 2)
        self.assertIn('id="top-navigation"', response)
        self.assertIn('id="site-navigation"', response)

    def test_menu_preferences_keep_a_navigation_path(self):
        response = render_shell('TOP_MENU=no; SIDE_MENU=yes; write_header "Example"; write_footer')
        self.assertIn('<nav', response)
        self.assertIn('sidebar', response)


if __name__ == '__main__':
    unittest.main()
