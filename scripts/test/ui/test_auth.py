"""Session behavior against synthetic files inside the disposable container."""
import os
import time
import unittest
from pathlib import Path
from shell_renderer import render_shell


class ExistingSessionTests(unittest.TestCase):
    def tearDown(self):
        Path('/tmp/cookie').unlink(missing_ok=True)

    def create_cookie(self, age=0):
        """Create an owned, synthetic session file, optionally expired."""
        cookie = Path('/tmp/cookie')
        cookie.write_text('fixture-session')
        cookie.chmod(0o600)
        moment = time.time() - age
        os.utime(cookie, (moment, moment))

    def test_valid_session_keeps_request_in_place(self):
        self.create_cookie()
        response = render_shell('check_cookie; printf authenticated', environment={'HTTP_COOKIE': 'ALTFID=fixture-session'})
        self.assertEqual(response, 'authenticated')

    def test_expired_session_does_not_render_protected_page(self):
        self.create_cookie(age=1900)
        response = render_shell('check_cookie; printf protected', environment={'HTTP_COOKIE': 'ALTFID=fixture-session'})
        self.assertIn('303', response)
        self.assertNotIn('protected', response)
        self.assertFalse(Path('/tmp/cookie').exists())

    def test_missing_cookie_returns_encoded_original_query(self):
        response = render_shell('check_cookie', environment={'REQUEST_URI': '/cgi-bin/host.cgi?name=nas&tab=network'})
        self.assertIn('%3F', response)
        self.assertIn('%26', response)
        self.assertNotIn('<html', response)


if __name__ == '__main__':
    unittest.main()
