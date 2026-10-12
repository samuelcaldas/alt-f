"""First-boot and theme contracts using synthetic, disposable container state."""
import unittest
from pathlib import Path
from shell_renderer import render_page, render_shell


class FirstBootTests(unittest.TestCase):
    def tearDown(self):
        Path('/tmp/firstboot').unlink(missing_ok=True)

    def test_pending_first_boot_still_redirects_to_current_step(self):
        Path('/tmp/firstboot').write_text('host')
        response = render_shell('write_header "Shares"; write_footer', script='smb.cgi')
        self.assertIn('Location: /cgi-bin/host.cgi', response)
        self.assertNotIn('<main', response)

    def test_existing_wizard_transition_is_preserved(self):
        Path('/tmp/firstboot').write_text('host')
        response = render_shell('gotopage /cgi-bin/host.cgi', script='host_proc.cgi')
        self.assertIn('Location: /cgi-bin/host.cgi', response)
        self.assertEqual(Path('/tmp/firstboot').read_text().strip(), 'time_1')

    def test_current_wizard_page_keeps_instructions(self):
        Path('/tmp/firstboot').write_text('time_1')
        response = render_shell('write_header "Time"; write_footer', script='time.cgi')
        self.assertIn('Continent/City', response)
        self.assertEqual(response.count('</main>'), 1)


class ThemeCompatibilityTests(unittest.TestCase):
    def test_classic_theme_keeps_new_navigation(self):
        theme = Path('/usr/www/scripts/default.thm')
        original = theme.readlink()
        try:
            theme.unlink()
            theme.symlink_to('classic.thm')
            response = render_page()
            self.assertIn('/scripts/classic/classic.css', response)
            self.assertIn('/scripts/ui/navigation.js', response)
            self.assertIn('<nav', response)
            self.assertNotIn('parent.frames', response)
        finally:
            theme.unlink(missing_ok=True)
            theme.symlink_to(original)


if __name__ == '__main__':
    unittest.main()
