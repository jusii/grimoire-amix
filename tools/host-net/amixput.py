#!/usr/bin/env python3
# amixput.py -- upload a local file to a networked Amix box via FTP (PASV), as root.
#
#   python3 amixput.py ./driver.o /tmp/driver.o
#
# Amix's in.ftpd is a classic 1990s server: PASV works, but it does not implement
# SIZE/MLSD -- so this uses only STOR. Override target/creds via env AMIX_HOST,
# AMIX_USER, AMIX_PASS. Root login can write anywhere (e.g. straight into /etc).
import os, sys
from ftplib import FTP

HOST = os.environ.get('AMIX_HOST', '192.168.2.38')
USER = os.environ.get('AMIX_USER', 'root')
PASS = os.environ.get('AMIX_PASS', 'changeme')   # set AMIX_PASS to your root password
local, remote = sys.argv[1], sys.argv[2]

f = FTP()
f.connect(HOST, int(os.environ.get('AMIX_PORT', '21')), timeout=25)
f.login(USER, PASS)
f.set_pasv(True)
with open(local, 'rb') as fp:
    f.storbinary('STOR ' + remote, fp)
print('stored', local, '->', remote)
f.quit()
