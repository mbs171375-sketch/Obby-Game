#!/usr/bin/env python3
"""Build and run meaningful offline checks, preserving every command's exit status."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--tools',type=Path,help='Directory containing luau, luau-compile and lune')
    args=parser.parse_args()
    def tool(name):
        value=str((args.tools/name).resolve()) if args.tools else shutil.which(name)
        if not value or not Path(value).is_file():parser.error(f'{name} missing; see README tool setup')
        return value
    luau,compiler,lune,analyzer=tool('luau'),tool('luau-compile'),tool('lune'),tool('luau-analyze')
    commands=[
        [sys.executable,'tools/build_place.py'],
        [sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py','-v'],
        [compiler,*[str(p.relative_to(ROOT)) for p in sorted((ROOT/'src').rglob('*.luau'))],'--null'],
        [analyzer,'src/shared/Rules.luau','src/shared/Config.luau'],
        [luau,'tests/rules.spec.luau'],
        [lune,'run','tests/client.spec.luau'],  # Also executes the production-server simulation.
        [lune,'run','tests/offline.spec.luau'],
        [lune,'run','tests/place.spec.luau'],   # Writes the binary deliverable after round-trip checks.
    ]
    output=[]
    for command in commands:
        print('+',' '.join(command),flush=True)
        result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        print(result.stdout,end='',flush=True)
        output.append('+ '+' '.join(command)+'\n'+result.stdout)
        if result.returncode:
            print('FAILED: stopping verification; no readiness claim.',file=sys.stderr)
            return result.returncode
    (ROOT/'docs/test-output.txt').write_text('\n'.join(output)+'\nOffline checks passed. Roblox gameplay, real purchases, audio playback and physical device rendering remain unverified.\n')
    print('Offline checks passed. See docs/VERIFICATION.md for limits and required external setup.')
    return 0

if __name__=='__main__':raise SystemExit(main())
