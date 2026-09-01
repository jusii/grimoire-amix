#!/usr/bin/env python3
# amixsh.py -- run shell commands on a networked Amix box over telnet, scripted.
#
# Logs in as root, runs each argv as one command, prints the captured output,
# exits. Designed for non-interactive / agent use (no PTY needed). Completion is
# detected with a marker emitted as  D''ONE_$?  so the echoed *input* line (which
# contains the quotes) never matches -- only the command's *output* does.
#
#   python3 amixsh.py 'ifconfig aen0' 'netstat -rn' 'ping www.google.com'
#
# Override target/credentials via env: AMIX_HOST, AMIX_USER, AMIX_PASS.
import os, re, socket, sys, time

HOST = os.environ.get('AMIX_HOST', '192.168.2.38')
PORT = int(os.environ.get('AMIX_PORT', '23'))
USER = (os.environ.get('AMIX_USER', 'root') + '\r\n').encode()
PW   = (os.environ.get('AMIX_PASS', 'changeme') + '\r\n').encode()   # set AMIX_PASS to your root password

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

def readuntil(sock, needles, timeout=25):
    sock.settimeout(1.0); buf = b''; end = time.time() + timeout
    while time.time() < end:
        try: chunk = sock.recv(4096)
        except socket.timeout: continue
        except OSError: break
        if not chunk: break
        buf += strip_iac(sock, chunk)
        if any(nd in buf for nd in needles): break
    return buf

s = socket.create_connection((HOST, PORT), timeout=20)
readuntil(s, [b'ogin:'], 30); s.sendall(USER)
readuntil(s, [b'assword:'], 15); s.sendall(PW)
readuntil(s, [b'# ', b'$ '], 25)
out = b''
rc_overall = 0
for c in sys.argv[1:]:
    s.sendall(c.encode() + b"; echo D''ONE_$?\r\n")
    buf = readuntil(s, [b'DONE_'], 60)
    # readuntil stops at the marker prefix -- the status digits may still be in
    # flight. Drain until DONE_<n> is complete (or give up and call it a hang).
    end = time.time() + 3
    while not re.search(rb'DONE_(\d+)', buf) and time.time() < end:
        s.settimeout(0.5)
        try: chunk = s.recv(4096)
        except socket.timeout: continue
        except OSError: break
        if not chunk: break
        buf += strip_iac(s, chunk)
    m = None
    for m in re.finditer(rb'DONE_(\d+)', buf): pass   # last match = this command's own echo
    rc = int(m.group(1)) if m else 124                # no complete marker = hang/transport loss
    if rc != 0 and rc_overall == 0: rc_overall = rc
    out += b'\n========== ' + c.encode() + b' ==========\n' + buf
try: s.sendall(b'exit\r\n')
except OSError: pass
sys.stdout.buffer.write(out); sys.stdout.flush()
# The remote status was always captured (DONE_$?) but never propagated -- so a
# caller's `set -e` could not fire on an on-box failure (half-patch audit F3).
sys.exit(rc_overall)
