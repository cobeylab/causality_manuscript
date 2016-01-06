#!/usr/bin/env python

import os
SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
import sys
sys.path.append(os.path.join(SCRIPT_DIR, 'pyembedding'))
import sqlite3
import numpy
import matplotlib
import random
matplotlib.use('Agg')
from matplotlib import pyplot
import json
from collections import OrderedDict

# Make sure pyembedding is set in $PYTHONPATH so these can be found, or do something like:
# sys.path.append(os.path.join(SCRIPT_DIR), 'pyembedding')
# if that's appropriate
import pyembedding
import projection
import models
import statutils
import npybuffer

def main():
    '''main(): gets called at the end (after other functions have been defined)'''

    # Load job info and record in database
    if not os.path.exists('runmany_info.json'):
        sys.stderr.write('runmany_info.json missing. aborting.\n')
        sys.exit(1)
    runmany_info = load_json('runmany_info.json')
    sim_db_path = runmany_info['simulation_db_path']
    job_info = runmany_info['job_info']

    # Make sure simulation database is present
    if not os.path.exists(sim_db_path):
        sys.stderr.write('Simulation database not present; aborting\n')
        sys.exit(1)

    # Connect to output database
    if os.path.exists('results.sqlite'):
        sys.stderr.write('Output database present. Aborting.\n')
        sys.exit(1)
    db = sqlite3.connect('results.sqlite')
    job_id = runmany_info['simulation_job_id']
    db.execute('CREATE TABLE job_info ({0})'.format(', '.join([key for key in job_info.keys()])))
    db.execute('INSERT INTO job_info VALUES ({0})'.format(', '.join(['?'] * len(job_info))), job_info.values())

    ccm_settings = runmany_info['ccm_settings']

    # Set up RNG
    rng = numpy.random.RandomState(job_info['random_seed'])
    X = load_simulation(sim_db_path, job_id, ccm_settings)
    if numpy.any(numpy.logical_or(
        numpy.isnan(X),
        numpy.isinf(X)
    )):
        sys.stderr.write('nans or infs in data; skipping all analyses.\n')
        sys.exit(0)
    
    x0 = X[:,0]
    x1 = X[:,1]

    variable_name = ccm_settings['variable_name']
    x0name = variable_name + '0'
    x1name = variable_name + '1'

    if ccm_settings['embedding_algorithm'] != 'plot':
        run_analysis(x0name, x0, x1name, x1, db, rng, ccm_settings)
        run_analysis(x1name, x1, x0name, x0, db, rng, ccm_settings)

    db.commit()
    db.close()

def load_simulation(sim_db_path, job_id, ccm_settings):
    '''Loads and processes time series based on settings at top of file.'''
    with sqlite3.connect(sim_db_path) as sim_db:
        buf = sim_db.execute(
            'SELECT {} FROM timeseries WHERE job_id = ?'.format(ccm_settings['variable_name']),
            [job_id]
        ).next()[0]
        assert isinstance(buf, buffer)
        arr = npybuffer.npy_buffer_to_ndarray(buf)
    assert arr.shape[1] == 2

    years = ccm_settings['years']
    simulation_samples_per_year = ccm_settings['simulation_samples_per_year']
    ccm_samples_per_year = ccm_settings['ccm_samples_per_year']

    # Get the unthinned sample from the end of the time series
    sim_samps_unthinned = years * simulation_samples_per_year
    thin = simulation_samples_per_year / ccm_samples_per_year
    arr_end_unthinned = arr[-sim_samps_unthinned:, :]
    
    # Thin the samples, adding in the intervening samples if requested
    arr_mod = arr_end_unthinned[::thin, :]
    if ccm_settings['add_samples']:
        for i in range(1, thin):
            arr_mod += arr_end_unthinned[i::thin, :]
    
    if ccm_settings['log_transform']:
        arr_mod = numpy.log(arr_mod)
    
    if ccm_settings['first_difference']:
        arr_mod = arr_mod[1:, :] - arr_mod[:-1, :]
    
    if ccm_settings['standardize']:
        for i in range(arr_mod.shape[1]):
            arr_mod[:,i] -= numpy.mean(arr_mod[:,i])
            arr_mod[:,i] /= numpy.std(arr_mod[:,i])


    if ccm_settings['first_difference']:
        assert arr_mod.shape[0] == years * ccm_samples_per_year - 1
    else:
        assert arr_mod.shape[0] == years * ccm_samples_per_year
    assert arr_mod.shape[1] == 2
    
    return arr_mod

def run_analysis(cname, cause, ename, effect, db, rng, ccm_settings):
    '''Run analysis for a single causal direction.'''
    sys.stderr.write('Running {0}-causes-{1}\n'.format(cname, ename))

    # Check if effect has no variation
    cause_sd = numpy.std(cause)
    effect_sd = numpy.std(effect)
    if cause_sd == 0.0 or effect_sd == 0.0:
        sys.stderr.write('No variation cause or effect time series; skipping analysis.\n')
        return
    else:
        # Identify delay at which autocorrelation drops to 1/e
        ac_delay, autocorr = pyembedding.autocorrelation_threshold_delay(effect, 1.0/numpy.e)
        sys.stderr.write('  ac_delay, autocorr = {0}, {1}\n'.format(ac_delay, autocorr))
        
        # Calculate Theiler window (limit on closeness of neighbors in time)
        theiler_window = min(ccm_settings['max_theiler_window'], 3 * ac_delay)
        sys.stderr.write('  theiler_window = {0}\n'.format(theiler_window))
        assert theiler_window < effect.shape[0]

        embedding_algorithm = ccm_settings['embedding_algorithm']
        assert embedding_algorithm == 'tajima_projection'
        if embedding_algorithm == 'tajima_projection':
            run_analysis_tajima_projection(cname, cause, ename, effect, theiler_window, db, rng, ccm_settings)

def run_analysis_tajima_projection(cname, cause, ename, effect, theiler_window, db, rng, ccm_settings):
    embedding = projection.tajima_cross_embedding(
        cause, effect, theiler_window,
        neighbor_count = None,
        corr_threshold = 1.00,
        rng = rng
    )
    
    sys.stderr.write('  Using embedding dimension = {}\n'.format(embedding.embedding_dimension))
    run_analysis_for_embedding(cname, cause, ename, effect, embedding, theiler_window, ccm_settings['n_ccm_bootstraps'], db, rng)

def run_analysis_for_embedding(cname, cause, ename, effect, embedding, theiler_window, n_bootstraps, db, rng):
    # min library size: embedding_dimension + 2,
    # so vectors should usually have embedding_dimension + 1 neighbors available
    Lmin = embedding.embedding_dimension + 2

    # max library size: just the number of available delay vectors
    Lmax = embedding.delay_vector_count

    assert Lmax > Lmin
    sys.stderr.write('  Using Lmin = {}, Lmax = {}\n'.format(Lmin, Lmax))

    corrs_Lmin = run_ccm_bootstraps(cname, ename, embedding, cause, Lmin, theiler_window, n_bootstraps, db, rng)
    corrs_Lmax = run_ccm_bootstraps(cname, ename, embedding, cause, Lmax, theiler_window, n_bootstraps, db, rng)

    db.execute(
        'CREATE TABLE IF NOT EXISTS ccm_increase (cause, effect, Lmin, Lmax, d, dmax, pvalue_increase)'
    )
    db.execute(
        'INSERT INTO ccm_increase VALUES (?,?,?,?,?,?,?)',
        [cname, ename, Lmin, Lmax, embedding.d, embedding.dmax, 1.0 - numpy.mean(statutils.inverse_quantile(corrs_Lmin, corrs_Lmax))]
    )
    db.commit()

def run_ccm(cname, ename, embedding, cause, theiler_window, db):
    assert isinstance(embedding, projection.ProjectionEmbedding)

    ccm_result, y_actual, y_pred = embedding.ccm(embedding, cause, theiler_window=theiler_window)
    db.execute('CREATE TABLE IF NOT EXISTS ccm_correlations_single (cause, effect, L, d, dmax, correlation)')
    db.execute(
        'INSERT INTO ccm_correlations_single VALUES (?,?,?,?,?,?)',
        [cname, ename, embedding.delay_vector_count, embedding.d, embedding.dmax, ccm_result['correlation']]
    )

    return ccm_result['correlation']

def run_ccm_bootstraps(cname, ename, embedding, cause, L, theiler_window, n_bootstraps, db, rng):
    assert isinstance(embedding, projection.ProjectionEmbedding)

    corrs = []

    for i in range(n_bootstraps):
        sampled_embedding = embedding.sample_embedding(L, replace=True, rng=rng)
        ccm_result, y_actual, y_pred = sampled_embedding.ccm(embedding, cause, theiler_window=theiler_window)

        corrs.append(ccm_result['correlation'])

    corrs = numpy.array(corrs)

    db.execute('CREATE TABLE IF NOT EXISTS ccm_correlation_dist (cause, effect, L, d, dmax, mean, sd, pvalue_positive, q0, q1, q2_5, q5, q25, q50, q75, q95, q97_5, q99, q100)')
    db.execute(
        'INSERT INTO ccm_correlation_dist VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [cname, ename, L, embedding.d, embedding.dmax, corrs.mean(), corrs.std(), statutils.inverse_quantile(corrs, 0.0).tolist()] +
            [x for x in numpy.percentile(corrs, [0, 1, 2.5, 5, 25, 50, 75, 95, 97.5, 99, 100])]
    )
    
    db.execute('CREATE TABLE IF NOT EXISTS ccm_correlations (cause, effect, L, d, dmax, correlation)')
    for corr in corrs:
        db.execute(
            'INSERT INTO ccm_correlations VALUES (?,?,?,?,?,?)',
            [cname, ename, L, embedding.d, embedding.dmax, corr]
    )

    return numpy.array(corrs)

def load_json(filename):
    with open(filename) as f:
        return json.load(f, object_pairs_hook=OrderedDict)

main()
