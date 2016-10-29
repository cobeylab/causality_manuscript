#!/usr/bin/env python

import os
import sys
import sqlite3
import numpy
from collections import OrderedDict

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))

N_RUNS = 100

def main():
    with sqlite3.connect(os.path.join(SCRIPT_DIR, 'results_gathered.sqlite')) as db:
        db.execute('DROP TABLE IF EXISTS ccm_lag_for_ggplot')
        db.execute('''CREATE TABLE IF NOT EXISTS ccm_lag_for_ggplot (
            replicate INTEGER,
            segment TEXT,
            cause TEXT,
            effect TEXT,
            neg_corr_med,
            neg_pvalue_best
        )''')
        
        for replicate in range(N_RUNS):
            for segment in ('start', 'mid', 'end'):
                add_job_row(db, replicate, segment, 'C0', 'C1')
                add_job_row(db, replicate, segment, 'C1', 'C0')
        
        db.execute('DROP TABLE IF EXISTS ccm_summary_for_ggplot')
        db.execute('''CREATE TABLE IF NOT EXISTS ccm_summary_for_ggplot (
            replicate INTEGER,
            detected_start_C0_causes_C1 INTEGER,
            detected_start_C1_causes_C0 INTEGER,
            success_start INTEGER,
            detected_mid_C0_causes_C1 INTEGER,
            detected_mid_C1_causes_C0 INTEGER,
            success_mid INTEGER,
            detected_end_C0_causes_C1 INTEGER,
            detected_end_C1_causes_C0 INTEGER,
            success_end INTEGER
        )''')
        
        for replicate in range(N_RUNS):
            add_summary_row(db, replicate)

def add_job_row(db, replicate, segment, cause, effect):
    try:
        job_id = db.execute(
            'SELECT job_id FROM job_info where replicate = ? AND segment = ?',
            [replicate, segment]
        ).next()[0]
        neg_corr_med, neg_pvalue_best = db.execute(
            'SELECT neg_corr_med, neg_pvalue_best FROM ccm_lag_tests WHERE job_id = ? AND cause = ? AND effect = ?',
            [job_id, cause, effect]
        ).next()
        db.execute(
            'INSERT INTO ccm_lag_for_ggplot VALUES (?,?,?,?,?,?)',
            [replicate, segment, cause, effect, neg_corr_med, neg_pvalue_best]
        )
    except Exception as e:
        print e

def add_summary_row(db, replicate):
    try:
        def get_detected(segment, cause, effect):
            pval = db.execute(
                'SELECT neg_pvalue_best FROM ccm_lag_for_ggplot WHERE replicate = ? AND segment = ? AND cause = ? AND effect = ?',
                [replicate, segment, cause, effect]
            ).next()[0]
            return pval <= 0.05
    
        s01 = get_detected('start', 'C0', 'C1')
        s10 = get_detected('start', 'C1', 'C0')
        m01 = get_detected('mid', 'C0', 'C1')
        m10 = get_detected('mid', 'C1', 'C0')
        e01 = get_detected('end', 'C0', 'C1')
        e10 = get_detected('end', 'C1', 'C0')
    
        db.execute('INSERT INTO ccm_summary_for_ggplot VALUES (?,?,?,?,?,?,?,?,?,?)', [
            replicate,
            s01, s10, not s01 and s10,
            m01, m10, not m01 and m10,
            e01, e10, not e01 and e10
        ])
    except Exception as e:
        print e

if __name__ == '__main__':
    main()
