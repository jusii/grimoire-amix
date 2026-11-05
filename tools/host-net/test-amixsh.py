#!/usr/bin/env python3
"""Tests for amixsh.py's exit status, against a fake telnet login and shell.

    python3 test-amixsh.py [path/to/amixsh.py]

No Amix box is involved, so this tests the script's logic, not a real tty. The
shell understands only:  true, false, hang, say <text>, sayhang <text>, echo <text>,
')' (a syntax error), and '<cmd> &' (runs <cmd>, status 0). A line holding '&;' is a
syntax error, as in the SVR4 Bourne shell. A line over 256 bytes wedges the login:
it and every later line answer nothing, as the canonical tty does.
"""
import os, re, socket, subprocess, sys, threading, time, unittest

AMIXSH = os.path.abspath(sys.argv.pop(1) if len(sys.argv) > 1
                         else os.path.join(os.path.dirname(__file__), 'amixsh.py'))
TIMEOUT = 2        # AMIX_TIMEOUT for these runs; a hang costs this many seconds
MAX_CANON = 256


class FakeAmix:
    """Accepts logins on a local port and records every command line it receives."""

    def __init__(self):
        self.lines = []
        self.logins = 0
        self.srv = socket.create_server(('127.0.0.1', 0))
        self.port = self.srv.getsockname()[1]
        threading.Thread(target=self._accept, daemon=True).start()

    def _accept(self):
        while True:
            try:
                conn, _ = self.srv.accept()
            except OSError:
                return
            threading.Thread(target=self._login, args=(conn,), daemon=True).start()

    def _login(self, conn):
        try:
            self._session(conn)
        except OSError:
            pass
        finally:
            conn.close()

    def _session(self, conn):
        self.logins += 1
        reader = conn.makefile('rb')
        conn.sendall(b'login: ')
        reader.readline()
        conn.sendall(b'Password: ')
        reader.readline()
        conn.sendall(b'# ')
        status = 0
        wedged = False
        while True:
            raw = reader.readline()
            if not raw:
                return
            text = raw.rstrip(b'\r\n')
            self.lines.append(text.decode(errors='replace'))
            wedged = wedged or len(raw) > MAX_CANON
            if wedged:
                continue
            conn.sendall(text + b'\r\n')       # the tty echoes the input line
            line = text.decode(errors='replace')
            if line == 'exit':
                return
            status = self._run_line(conn, line, status)
            if status is None:                 # stuck: read on, answer nothing
                while reader.readline():
                    pass
                return
            conn.sendall(b'# ')

    def _run_line(self, conn, line, status):
        if '&;' in line.replace(' ', '') or line.strip() == ')':
            conn.sendall(b'sh: syntax error\r\n')
            return 2
        for part in re.split(r';\s*', line):
            part = part.strip()
            if part.endswith('&'):
                self._run_one(conn, part[:-1].strip(), status)
                status = 0
                continue
            status = self._run_one(conn, part, status)
            if status is None:
                return None
        return status

    @staticmethod
    def _run_one(conn, cmd, status):
        if cmd == 'false':
            return 255                         # as on Amix
        if cmd == 'hang':
            return None
        for word, then in (('say ', 0), ('sayhang ', None)):
            if cmd.startswith(word):
                conn.sendall(cmd[len(word):].encode() + b'\r\n')
                return then
        if cmd.startswith('echo '):
            text = cmd[5:].replace("''", '').replace('$?', str(status))
            conn.sendall(text.encode() + b'\r\n')
        return 0

    def close(self):
        self.srv.close()


class AmixshTest(unittest.TestCase):
    def setUp(self):
        self.box = FakeAmix()
        self.addCleanup(self.box.close)

    def run_amixsh(self, *commands, timeout=TIMEOUT):
        env = dict(os.environ, AMIX_HOST='127.0.0.1', AMIX_PORT=str(self.box.port),
                   AMIX_PASS='x', AMIX_TIMEOUT=str(timeout))
        started = time.time()
        proc = subprocess.run([sys.executable, AMIXSH, *commands], env=env,
                              capture_output=True, timeout=90)
        self.elapsed = time.time() - started
        self.stderr = proc.stderr.decode()
        self.stdout = proc.stdout.decode()
        return proc.returncode

    def sent(self):
        return [l for l in self.box.lines if "ONE_" not in l and l not in ('root', 'x', 'exit')]

    # the status the box reports
    def test_true_is_0(self):
        self.assertEqual(self.run_amixsh('true'), 0)

    def test_false_is_255(self):
        self.assertEqual(self.run_amixsh('false'), 255)

    def test_first_failure_sticks(self):
        self.assertEqual(self.run_amixsh('false', 'true'), 255)
        self.assertEqual(self.sent(), ['false', 'true'])

    # a command over the line limit
    def test_over_limit_is_refused_before_connecting(self):
        self.assertEqual(self.run_amixsh('true', 'say ' + 'x' * 300), 2)
        self.assertEqual(self.box.logins, 0)
        self.assertIn('over the 237-byte limit', self.stderr)

    def test_limit_is_exact(self):
        self.assertEqual(self.run_amixsh('say ' + 'x' * 233), 0)
        self.assertEqual(self.box.logins, 1)
        self.assertEqual(self.run_amixsh('say ' + 'x' * 234), 2)
        self.assertEqual(self.box.logins, 1)

    def test_limit_counts_bytes(self):
        self.assertEqual(self.run_amixsh('say ' + 'ä' * 117), 2)

    def test_limit_is_per_line(self):
        self.assertEqual(self.run_amixsh('say a\n' * 60 + 'say b'), 0)

    # a command that never finishes
    def test_hang_is_124_with_a_reason(self):
        self.assertEqual(self.run_amixsh('hang'), 124)
        self.assertIn('no end marker', self.stderr)

    def test_timeout_is_settable(self):
        self.run_amixsh('hang', timeout=1)
        self.assertLess(self.elapsed, TIMEOUT)

    def test_nothing_is_sent_after_a_hang(self):
        self.assertEqual(self.run_amixsh('hang', 'say later', 'true'), 124)
        self.assertEqual(self.sent(), ['hang'])
        self.assertIn('2 later command(s) not sent', self.stderr)

    def test_failure_before_a_hang_keeps_its_status(self):
        self.assertEqual(self.run_amixsh('false', 'hang'), 255)

    def test_output_before_a_hang_is_kept(self):
        self.run_amixsh('sayhang partial')
        self.assertIn('partial', self.stdout)

    # marker text in a command or its output is not the marker
    def test_marker_in_command_text_then_hang(self):
        self.assertEqual(self.run_amixsh('say DONE_0; hang'), 124)

    def test_marker_in_output_then_hang(self):
        self.assertEqual(self.run_amixsh('sayhang DONE_0'), 124)

    def test_marker_in_command_text_then_fail(self):
        self.assertEqual(self.run_amixsh('say DONE_0; false'), 255)

    def test_marker_in_output_does_not_mask_the_next_command(self):
        self.assertEqual(self.run_amixsh('say DONE_0', 'false'), 255)

    # a command's own ending does not disturb the marker
    def test_trailing_ampersand_runs(self):
        self.assertEqual(self.run_amixsh('say bg &'), 0)
        self.assertIn('bg\r\n', self.stdout)

    def test_syntax_error_is_not_0(self):
        self.assertEqual(self.run_amixsh(')'), 2)

    # what callers filter on still matches
    def test_marker_line_matches_old_filters(self):
        self.run_amixsh('true')
        self.assertRegex(self.stdout, r'DONE_0')
        self.assertRegex(self.stdout, r'echo D')


if __name__ == '__main__':
    unittest.main(verbosity=1)
