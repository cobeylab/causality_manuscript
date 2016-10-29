#!/usr/bin/env python

import os
import sys
import json

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))

for i in range(20):
    job_dir = os.path.join('jobs', '{}'.format(i))
    os.makedirs(job_dir)
    
    runmany_info = {
        'executable' : os.path.join(SCRIPT_DIR, 'transient.py'),
        'megabytes' : 2000,
        'minutes' : 240
    }
    
    with open(os.path.join(job_dir, 'runmany_info.json'), 'w') as f:
        json.dump(runmany_info, f, indent=2)
        f.write('\n')
