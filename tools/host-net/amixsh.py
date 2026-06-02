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
import os, socket, sys, time

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
for c in sys.argv[1:]:
    s.sendall(c.encode() + b"; echo D''ONE_$?\r\n")
    out += b'\n========== ' + c.encode() + b' ==========\n' + readuntil(s, [b'DONE_'], 60)
try: s.sendall(b'exit\r\n')
except OSError: pass
sys.stdout.buffer.write(out); sys.stdout.flush()
