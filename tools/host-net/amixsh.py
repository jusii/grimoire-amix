#!/usr/bin/env python3
# amixsh.py -- run shell commands on a networked Amix box over telnet, scripted.
#
# Logs in as root, runs each argv as one command, prints the captured output,
# exits. Designed for non-interactive / agent use (no PTY needed).
#
#   python3 amixsh.py 'ifconfig aen0' 'netstat -rn' 'ping www.google.com'
#
# Completion is detected with a marker line sent after each command, so a command
# may end in '&' or a comment. It prints as DONE_<status>_<nonce>; the nonce is new
# each run, so neither the command's text nor its output can pass for the marker,
# and the quotes in  echo D''ONE_$?_<nonce>  keep the echoed input from matching.
#
# Exit status: the first non-zero status from the box; 2 for a line too long to
# send (nothing is sent, not even a login); 124 when a command's marker does not
# arrive (still running, line wedged, or connection lost). Commands after a 124
# are not sent.
#
# Override target/credentials via env: AMIX_HOST, AMIX_PORT, AMIX_USER, AMIX_PASS.
# AMIX_TIMEOUT is the seconds to wait for each command (default 60).
import os, re, socket, sys, time

HOST = os.environ.get('AMIX_HOST', '192.0.2.38')   # RFC 5737 example; set AMIX_HOST
PORT = int(os.environ.get('AMIX_PORT', '23'))
USER = (os.environ.get('AMIX_USER', 'root') + '\r\n').encode()
PW   = (os.environ.get('AMIX_PASS', 'changeme') + '\r\n').encode()   # set AMIX_PASS to your root password
TIMEOUT = int(os.environ.get('AMIX_TIMEOUT', '60'))

# A canonical tty line holds 256 bytes. Past that the tty discards the overrun and
# the newline, nothing runs, and the rest of the login answers nothing. 237 is the
# budget with a 16-byte marker on the line, kept so a line that fits here fits any
# tool that does that.
MAX_LINE = 237

NONCE = os.urandom(3).hex()
MARKER_CMD = ("echo D''ONE_$?_%s\r\n" % NONCE).encode()
MARKER_RE = re.compile(rb'DONE_(\d+)_' + NONCE.encode())

def strip_iac(sock, data):
    """Strip/answer telnet IAC negotiation; refuse all options (WONT/DONT)."""
    out = bytearray(); resp = bytearray(); i = 0; n = len(data)
    while i < n:
        b = data[i]
        if b == 0xff:
            if i + 1 >= n: break
            c = data[i+1]
            if c in (0xfb, 0xfc, 0xfd, 0xfe) and i + 2 < n:
                opt = data[i+2]
                if c == 0xfd: resp += bytes([0xff, 0xfc, opt])   # DO   -> WONT
                elif c == 0xfb: resp += bytes([0xff, 0xfe, opt]) # WILL -> DONT
                i += 3; continue
            elif c == 0xff:
                out.append(0xff); i += 2; continue
            else:
                i += 2; continue
        out.append(b); i += 1
    if resp:
        try: sock.sendall(bytes(resp))
        except OSError: pass
    return bytes(out)

def readuntil(sock, found, timeout=25):
    """Read until found(buf) is true, the timeout passes, or the connection ends."""
    sock.settimeout(1.0); buf = b''; end = time.time() + timeout
    while time.time() < end:
        try: chunk = sock.recv(4096)
        except socket.timeout: continue
        except OSError: break
        if not chunk: break
        buf += strip_iac(sock, chunk)
        if found(buf): break
    return buf

for c in sys.argv[1:]:
    longest = max(len(line) for line in c.encode().split(b'\n'))
    if longest > MAX_LINE:
        sys.stderr.write("amixsh: a line of %d bytes is over the %d-byte limit, nothing "
                         "sent; split it into several arguments (same login): %s...\n"
                         % (longest, MAX_LINE, c[:60]))
        sys.exit(2)

s = socket.create_connection((HOST, PORT), timeout=20)
readuntil(s, lambda b: b'ogin:' in b, 30); s.sendall(USER)
readuntil(s, lambda b: b'assword:' in b, 15); s.sendall(PW)
readuntil(s, lambda b: b'# ' in b or b'$ ' in b, 25)
out = b''
rc_overall = 0
missed = None
for n, c in enumerate(sys.argv[1:]):
    try: s.sendall(c.encode() + b'\r\n' + MARKER_CMD)
    except OSError: buf = b''
    else: buf = readuntil(s, MARKER_RE.search, TIMEOUT)
    out += b'\n========== ' + c.encode() + b' ==========\n' + buf
    m = MARKER_RE.search(buf)
    if not m:
        rc_overall = rc_overall or 124
        missed = "amixsh: no end marker within %d s, the command is still running or " \
                 "the line was lost; %d later command(s) not sent: %s\n" \
                 % (TIMEOUT, len(sys.argv) - 2 - n, c[:60])
        break
    rc_overall = rc_overall or int(m.group(1))
try: s.sendall(b'exit\r\n')
except OSError: pass
sys.stdout.buffer.write(out); sys.stdout.flush()
if missed: sys.stderr.write(missed)
sys.exit(rc_overall)
