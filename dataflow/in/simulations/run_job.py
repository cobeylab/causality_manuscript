#!/usr/bin/env python
'''
    Runs a single SIR model simulation: uses parameters defined here overridden by sir_params.json
    Saves output of model in .npy data format as binary blob SQLite records, to be space-efficient.
'''

import os
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
import sys
sys.path.append(os.path.join(SCRIPT_DIR, 'pyembedding'))
from datetime import datetime
import sqlite3
from cStringIO import StringIO
import numpy
import matplotlib
import random
matplotlib.use('Agg')
from matplotlib import pyplot
import json
from collections import OrderedDict

import jsonobject
import models

# Connect to output database
if os.path.exists('results.sqlite'):
    sys.stderr.write('Output database present. Aborting.\n')
    sys.exit(1)
db = sqlite3.connect('results.sqlite')

# Load job info and record in database
if os.path.exists('job_info.json'):
    job_info = jsonobject.load_from_file('job_info.json')
else:
    job_info = jsonobject.JSONObject()
    job_info.random_seed = random.SystemRandom().randint(1, 2**31-1)
db.execute('CREATE TABLE job_info ({0})'.format(', '.join([key for key in job_info.keys()])))
db.execute('INSERT INTO job_info VALUES ({0})'.format(', '.join(['?'] * len(job_info))), job_info.values())

# Set up RNG
rng = numpy.random.RandomState(job_info.random_seed)

# Initialize SIR model parameters: first defaults,
# then load overrides from JSON file if present
params = jsonobject.JSONObject(
    random_seed = rng.randint(1, 2**31 - 1),
    n_pathogens = 2,

    dt_euler = 0.01,
    adaptive = False,
    tol = 1e-6,
    t_end = 360.0 * 3000,
    dt_output = 10.0,

    mu = 0.000555556,
    nu = [0.2, 0.2],
    gamma = [0.0, 0.0],

    beta0 = [0.3, 0.25],
    S_init = [1.0, 1.0], # Initialized below
    I_init = [0.0, 0.0], # Initialized below
    beta_change_start = [0.0, 0.0],
    beta_slope = [0.0, 0.0],
    psi = [360.0, 360.0],
    omega = [-0.25, -0.25],
    eps = [0.0, 0.0],
    sigma = [[1.0, 0.0], [0.0, 1.0]],

    shared_proc = False,
    sd_proc = [0.0, 0.0],

    shared_obs = False,
    sd_obs = [0.0, 0.0],

    shared_obs_C = False,
    sd_obs_C = [0.0, 0.0]
)
params.S_init = rng.uniform(0.0, 1.0, size=params.n_pathogens)
params.I_init = rng.uniform(0.0, 1.0 - params.S_init)
if os.path.exists('sir_params.json'):
    params.update_from_file('sir_params.json')

# main(): gets called at the end (after other functions have been defined)
def main():
    start_time = datetime.utcnow()
    sys.stderr.write('{} : simulation starting\n'.format(start_time))
    sir_out = run_simulation()
    end_time = datetime.utcnow()
    sys.stderr.write('{} : simulation done\n'.format(end_time))
    sys.stderr.write('elapsed time {}\n'.format(end_time - start_time))
    
    t = numpy.arange(1000*36) / 36.0
    logS = sir_out.logS[-36000:, :]
    logI = sir_out.logI[-36000:, :]
    C = sir_out.C[-36000:, :]
    
    plot_timeseries(t[-3600:], [C[-3600:,0], C[-3600:,1]], ['C0', 'C1'], 'time (years)', '10-day cases', 'timeseries.png')
    write_timeseries(logS, logI, C)

    db.commit()
    db.close()

def plot_timeseries(t, series, labels, xlabel, ylabel, filename):
    fig = pyplot.figure(figsize=(12,4))
    for x in series:
        pyplot.plot(t, x)
    pyplot.legend(labels)
    pyplot.xlabel(xlabel)
    pyplot.ylabel(ylabel)
    pyplot.savefig(filename)
    pyplot.close(fig)

def write_timeseries(logS, logI, C):
    db.execute('CREATE TABLE timeseries (logS BLOB, logI BLOB, C BLOB)')
    db.execute(
        'INSERT INTO timeseries VALUES (?, ?, ?)',
        [array_to_buffer(logS), array_to_buffer(logI), array_to_buffer(C)]
    )

def array_to_buffer(arr):
    f = StringIO()
    numpy.save(f, arr)
    data = f.getvalue()
    f.close()
    return buffer(data)

def run_simulation():
    try:
        db.execute('CREATE TABLE sir_params (params TEXT)')
        db.execute('INSERT INTO sir_params VALUES (?)', (params.dump_to_string(),))

        return models.run_via_pypy('multistrain_sde', params)
    except models.ExecutionException as e:
        sys.stderr.write('An exception occurred trying to run simulation...\n')
        sys.stderr.write('{0}\n'.format(e.cause))
        sys.stderr.write(e.stderr_data)
        sys.exit(1)

main()
