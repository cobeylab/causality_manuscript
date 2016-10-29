#!/usr/bin/env python

import os
import sys
import sqlite3
import numpy
from collections import OrderedDict

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))

N_RUNS = 100

BURNIN_YEARS = 1000

def main():
    for i in range(N_RUNS):
        add_job_info(i)

def add_job_info(i):
    dirname = os.path.join(SCRIPT_DIR, 'jobs',
        '{:02d}'.format(i)
    )
    sys.stderr.write('Processing {}\n'.format(dirname))
    
    for segment in ('start', 'mid', 'end'):
        sys.stderr.write('  ({})\n'.format(segment))
        db_filename = os.path.join(dirname, 'results_{}.sqlite'.format(segment))
        with sqlite3.connect(db_filename) as db:
            db.execute('DROP TABLE IF EXISTS job_info')
            db.execute('''CREATE TABLE job_info (
                replicate INTEGER,
                segment TEXT
            )''')
            db.execute('INSERT INTO job_info VALUES (?,?)', [
                i,
                segment
            ])

if __name__ == '__main__':
    main()
