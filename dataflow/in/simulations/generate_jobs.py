#!/usr/bin/env python

import os
import sys
import numpy

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
os.chdir(SCRIPT_DIR)

import random
seed_rng = random.SystemRandom()

sys.path.append(os.path.join(SCRIPT_DIR, 'pyembedding'))
from jsonobject import JSONObject

eps_vals = ['0.0', '0.1']
beta00_vals = ['0.25', '0.30']
beta01 = 0.25
sigma01_vals = ['0.00', '0.25', '0.50', '1.00']
sd_proc_vals = ['1e-6', '0.001', '0.010', '0.050', '0.100']
n_replicates = 100

if os.path.exists('jobs'):
    sys.stderr.write('jobs already exists; aborting.\n')
    sys.exit(1)

for eps in eps_vals:
    for beta00 in beta00_vals:
        for sigma01 in sigma01_vals:
            for sd_proc in sd_proc_vals:
                for replicate_id in range(n_replicates):
                    job_dir = os.path.join(
                        'jobs',
                        '-'.join([
                            'eps={}'.format(eps),
                            'beta00={}'.format(beta00),
                            'sigma01={}'.format(sigma01),
                            'sd_proc={}'.format(sd_proc)
                        ]),
                        '{:03d}'.format(replicate_id)
                    )
                    sys.stderr.write('{0}\n'.format(job_dir))
                    os.makedirs(job_dir)
                    
                    # Write information to be used in jobs table
                    # (NOTE: parameters must also be included below in format accepted by SIR simulation.)
                    JSONObject([
                        ('job_dir', job_dir),
                        ('eps', float(eps)),
                        ('beta00', float(beta00)),
                        ('sigma01', float(sigma01)),
                        ('sd_proc', float(sd_proc)),
                        ('replicate_id', replicate_id),
                        ('random_seed', seed_rng.randint(1, 2**31-1))
                    ]).dump_to_file(os.path.join(job_dir, 'job_info.json'))
                    
                    # Write simulation parameters to JSON file
                    JSONObject([
                        ('eps', [float(eps)]*2),
                        ('beta0', [float(beta00), beta01]),
                        ('sigma', [[1.0, float(sigma01)], [0.0, 1.0]]),
                        ('sd_proc', [float(sd_proc)]*2),
                    ]).dump_to_file(os.path.join(job_dir, 'sir_params.json'))
