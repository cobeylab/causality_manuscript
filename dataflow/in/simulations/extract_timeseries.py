#!/usr/bin/env python

import os
import sys
import random
import sqlite3
from collections import OrderedDict
import json

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.append(os.path.join(SCRIPT_DIR, '..', '..'))
import npybuffer

# Simulations database: make sure this is an absolute path
SIM_DB_PATH = '/Users/ebaskerv/uchicago/midway_cobey/ccmproject-storage/2015-10-23-simulations/results_gathered.sqlite'
#SIM_DB_PATH = '/project/cobey/ccmproject-storage/2015-10-23-simulations/results_gathered.sqlite'

def main():
    outdb_path = os.path.join(SCRIPT_DIR, 'timeseries.sqlite')
    if os.path.exists(outdb_path):
        sys.stderr.write('timeseries.sqlite already exists; aborting.\n')
        sys.exit(1)
    outdb = sqlite3.connect(outdb_path)
    outdb.execute('CREATE TABLE job_info (job_id, eps, beta00, sigma01, sd_proc, replicate_id)')
    outdb.execute('CREATE TABLE timeseries (job_id, ind, logI0, logI1, C0, C1)')
    
    if not os.path.exists(SIM_DB_PATH):
        sys.stderr.write('simulations DB not present; aborting.\n')
        sys.exit(1)
    
    with sqlite3.connect(SIM_DB_PATH) as db:
        for job_id, eps, beta00, sigma01, sd_proc, replicate_id in db.execute(
            'SELECT job_id, eps, beta00, sigma01, sd_proc, replicate_id FROM job_info'
        ):
            sys.stderr.write('{}, {}, {}, {}, {}, {}\n'.format(job_id, eps, beta00, sigma01, sd_proc, replicate_id))
            job_id, logIbuf, Cbuf = db.execute('SELECT job_id, logI, C FROM timeseries WHERE job_id = ?', [job_id]).next()
            outdb.execute('INSERT INTO job_info VALUES (?,?,?,?,?,?)', [job_id, eps, beta00, sigma01, sd_proc, replicate_id])
            
            logI = npybuffer.npy_buffer_to_ndarray(logIbuf)[::3,:]
            C = npybuffer.npy_buffer_to_ndarray(Cbuf)[::3,:]
            
            for i in range(logI.shape[0]):
                outdb.execute('INSERT INTO timeseries VALUES (?,?,?,?,?,?)', [job_id, i, logI[i,0], logI[i,1], C[i,0], C[i,1]])
            outdb.commit()
    
    outdb.execute('CREATE INDEX job_info_index ON job_info (job_id, eps, beta00, sigma01, sd_proc, replicate_id)')
    outdb.execute('CREATE INDEX timeseries_index ON timeseries (job_id, ind)')
    outdb.commit()
    
    outdb.close()

if __name__ == '__main__':
    main()
