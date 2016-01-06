#!/usr/bin/env python

import subprocess
import os
import sys
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
os.chdir(SCRIPT_DIR)

def main():
    run('pdflatex', 'ccm_ms')
    try:
        run('bibtex', 'ccm_ms')
    except Exception as e:
        pass
    run('pdflatex', 'ccm_ms')
    run('pdflatex', 'ccm_ms')
    run('rm', 'ccm_ms.aux')
    run('rm', 'ccm_ms.blg')
    run('rm', 'ccm_ms.log')

def run(*args):
    proc = subprocess.Popen(args)
    result = proc.wait()
    if result != 0:
        raise Exception('Execution failed: {0}'.format(args))

if __name__ == '__main__':
    main()
