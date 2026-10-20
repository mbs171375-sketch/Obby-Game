#!/usr/bin/env python3
"""Optional Linux x86_64 verification tools, pinned to TLS-fetched upstream releases."""
import argparse
import hashlib
import io
from pathlib import Path
import platform
import urllib.request
import zipfile

TOOLS = [
    ('https://github.com/luau-lang/luau/releases/download/0.743/luau-ubuntu.zip',
     '99d45afb4afaee00ba631c526c8e8c76c67b60f6f119953ce6409be6d6953663',
     ('luau','luau-compile','luau-analyze','luau-ast')),
    ('https://github.com/lune-org/lune/releases/download/v0.11.0/lune-0.11.0-linux-x86_64.zip',
     '5a0ea32c3e13e5e3b1dc415c2056bcfe44258b3a811dcd473c50e3b437d10f72',('lune',)),
]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--destination',type=Path,default=Path('.test-output/tools'))
    args=parser.parse_args()
    if platform.system()!='Linux' or platform.machine() not in ('x86_64','AMD64'):
        parser.error('These pinned binaries are Linux x86_64 only; use upstream tools for your platform.')
    args.destination.mkdir(parents=True,exist_ok=True)
    for url,checksum,members in TOOLS:
        print('Downloading',url)
        with urllib.request.urlopen(url,timeout=60) as response:data=response.read()
        if hashlib.sha256(data).hexdigest()!=checksum:raise RuntimeError('Release checksum mismatch; refusing to install')
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for member in members:
                if member not in archive.namelist():continue
                output=args.destination/member
                output.write_bytes(archive.read(member));output.chmod(0o755)
                print('Verified and installed',output)

if __name__=='__main__':main()
