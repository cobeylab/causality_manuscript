#!/usr/bin/env python

import os
import sys
import numpy
import json

def main():
    in_filename = sys.argv[1]
    x = numpy.load(in_filename)
    
    out_filename = '{}.json'.format(os.path.splitext(in_filename)[0])
    with open(out_filename, 'w') as f:
        json.dump(x.tolist(), f)
        f.write('\n')

if __name__ == '__main__':
    main()
