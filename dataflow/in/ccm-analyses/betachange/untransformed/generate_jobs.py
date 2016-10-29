#!/usr/bin/env python

import os
import sys
import json
import numpy
from collections import OrderedDict

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))

N_RUNS = 100
burnin_years = 1000
years= 100

def main():
    base_params = load_json(os.path.join(SCRIPT_DIR, 'base_params.json'))
    for i in range(N_RUNS):
        write_params(base_params, i)

def write_params(base_params, i):
    params = OrderedDict(base_params)
    params['random_seed'] = numpy.random.randint(1, 2**31 - 1)
    params['I_init'][0] = numpy.random.uniform(0.0, 0.01)
    params['I_init'][1] = numpy.random.uniform(0.0, 0.01)
    params['S_init'][0] = numpy.random.uniform(0.8, 0.99)
    params['S_init'][1] = numpy.random.uniform(0.8, 0.99)
    params['t_end'] = 360 * (burnin_years * 2 + years * 3)
    
    params['beta_change_start_t'] = [(burnin_years + years) * 360, (burnin_years + years) * 360]
    params['beta_change_final_t'] = [(burnin_years + 2 * years) * 360, (burnin_years + 2 * years) * 360]
    
    dirname = os.path.join(SCRIPT_DIR, 'jobs', '{:02d}'.format(i))
    os.makedirs(dirname)
    dump_json(params, os.path.join(dirname, 'params.json'))
    dump_json(
        {'PYEMBEDDING_DIR' : os.path.relpath(os.path.join(SCRIPT_DIR, 'pyembedding'), dirname)},
        os.path.join(dirname, 'config.json')
    )
    
    ccm_params = OrderedDict([
        ('samples_per_year', 12),
        ('start_range', [burnin_years, burnin_years + years]),
        ('mid_range', [burnin_years + years, burnin_years + 2 * years]),
        ('end_range', [2 * burnin_years + 2 * years, 2 * burnin_years + 3 * years])
    ])
    dump_json(ccm_params, os.path.join(dirname, 'ccm_params.json'))

def load_json(filename):
    with open(filename) as f:
        return json.load(f, object_pairs_hook=OrderedDict)

def dump_json(obj, filename):
    with open(filename, 'w') as f:
        json.dump(obj, f, indent=2)
        f.write('\n')

if __name__ == '__main__':
    main()
