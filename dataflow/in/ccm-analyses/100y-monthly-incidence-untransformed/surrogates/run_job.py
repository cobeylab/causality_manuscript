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
    
    plot_timeseries([x0, x1], [x0name, x1name], ccm_settings['timeseries_x_label'], ccm_settings['timeseries_y_label'], 'timeseries.png')
    
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
    if 'simulation_samples_offset' in ccm_settings:
        sim_samps_unthinned -= ccm_settings['simulation_samples_offset']
        print sim_samps_unthinned
    
    thin = int(simulation_samples_per_year / ccm_samples_per_year)
    arr_end_unthinned = arr[-sim_samps_unthinned:, :]
    
    # Thin the samples, adding in the intervening samples if requested
    arr_mod = arr_end_unthinned[::thin, :]
    if ccm_settings['add_samples']:
        for i in range(1, thin):
            arr_mod += arr_end_unthinned[i::thin, :]
    
    if ccm_settings['transform'] == 'log':
        arr_mod = numpy.log(arr_mod)
    elif ccm_settings['transform'] == 'exp':
        arr_mod = numpy.exp(arr_mod)
    
    if ccm_settings['first_difference']:
        arr_mod = arr_mod[1:, :] - arr_mod[:-1, :]
    
    if ccm_settings['standardize']:
        for i in range(arr_mod.shape[1]):
            arr_mod[:,i] -= numpy.mean(arr_mod[:,i])
            arr_mod[:,i] /= numpy.std(arr_mod[:,i])


    if ccm_settings['first_difference']:
        assert arr_mod.shape[0] == int(years * ccm_samples_per_year) - 1
    else:
        print arr_mod.shape[0]
        print years * ccm_samples_per_year
        assert arr_mod.shape[0] == int(years * ccm_samples_per_year)
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
        assert embedding_algorithm == 'max_univariate_prediction'
        run_analysis_max_univariate_prediction(cname, cause, ename, effect, theiler_window, db, rng, ccm_settings)

def run_analysis_max_univariate_prediction(cname, cause, ename, effect, theiler_window, db, rng, ccm_settings):
    if 'delta_tau_termination' in ccm_settings:
        delta_tau_termination = ccm_settings['delta_tau_termination']
    else:
        delta_tau_termination = None
    
    max_corr = float('-inf')
    max_corr_Etau = None
    for E in ccm_settings['sweep_embedding_dimensions']:
        if delta_tau_termination is not None:
            max_corr_this_E = float('-inf')
            max_corr_tau_this_E = None
        
        for tau in (ccm_settings['sweep_delays'] if E > 1 else [1]):
            delays = tuple(range(0, E*tau, tau))
            embedding = pyembedding.Embedding(effect[:-1], delays)
            if embedding.delay_vector_count < embedding.embedding_dimension + 2:
                sys.stderr.write('  Lmax < Lmin; skipping E={}, tau={}\n'.format(E, tau))
                continue

            eff_off, eff_off_pred = embedding.simplex_predict_using_embedding(embedding, effect[1:], theiler_window=theiler_window)
            corr = numpy.corrcoef(eff_off, eff_off_pred)[0,1]

            #db.execute('CREATE TABLE IF NOT EXISTS univariate_predictions (variable, delays, correlation)')
            #db.execute('INSERT INTO univariate_predictions VALUES (?,?,?)', [ename, str(delays), corr])

            sys.stderr.write('  corr for E={}, tau={} : {}\n'.format(E, tau, corr))
            if corr > max_corr:
                max_corr = corr
                max_corr_Etau = (E, tau)
            
            if delta_tau_termination is not None:
                if corr > max_corr_this_E:
                    max_corr_this_E = corr
                    max_corr_tau_this_E = tau
            
                if E * (tau - max_corr_tau_this_E) >= delta_tau_termination:
                    sys.stderr.write('{} taus since a maximum for this E; assuming found.\n'.format(delta_tau_termination))
                    break
    
    E, tau = max_corr_Etau
    delays = tuple(range(0, E*tau, tau))
    
    sys.stderr.write('  Using E = {}, tau = {}\n'.format(*max_corr_Etau))
    run_analysis_surrogates(cname, cause, ename, effect, delays, theiler_window, ccm_settings['n_ccm_bootstraps'], db, rng)

def calculate_mean_anomaly(ts, period):
    mean = numpy.zeros(period, dtype=float)
    for i in range(period):
        mean[i] = numpy.mean(ts[i::period])
    
    anomaly = numpy.zeros_like(ts)
    for i in range(period):
        anomaly[i::period] = ts[i::period] - mean[i]
    
    return mean, anomaly

def randomize_surrogate(mean, anomaly, rng):
    ts = numpy.zeros_like(anomaly)
    anom_perm = rng.permutation(anomaly)
    period = mean.shape[0]
    for i in range(period):
        ts[i::period] = mean[i] + anom_perm[i::period]
    return ts

def run_analysis_surrogates(cname, cause, ename, effect, delays, theiler_window, n_bootstraps, db, rng):
    #db.execute('CREATE TABLE IF NOT EXISTS surrogate_corrs (cause, effect, use_effect_surrogates, correlation)');
    db.execute('CREATE TABLE IF NOT EXISTS surrogate_test (cause, effect, use_effect_surrogates, corr_raw, corr_surr_q95, pvalue_greater)')
    db.execute('CREATE TABLE IF NOT EXISTS surrogate_dist (cause, effect, use_effect_surrogates, q0, q1, q2_5, q5, q25, q50, q75, q95, q97_5, q99, q100)')
    
    effect_raw_embedding = pyembedding.Embedding(effect, delays)
    corr_raw = effect_raw_embedding.ccm(effect_raw_embedding, cause, theiler_window=theiler_window)[0]['correlation']
    
    # Run with cause surrogates only
    cause_mean, cause_anom = calculate_mean_anomaly(cause, 12)
    corrs_cause_only = []
    for i in range(n_bootstraps):
        cause_surr = randomize_surrogate(cause_mean, cause_anom, rng)
        ccm_result, y_actual, y_pred = effect_raw_embedding.ccm(effect_raw_embedding, cause_surr, theiler_window=theiler_window)
        corrs_cause_only.append(ccm_result['correlation'])
        #db.execute('INSERT INTO surrogate_corrs VALUES (?,?,?,?)', [cname, ename, 0, ccm_result['correlation']])
    db.execute('INSERT INTO surrogate_test VALUES (?,?,?,?,?,?)', [cname, ename, 0,
        corr_raw,
        numpy.percentile(corrs_cause_only, 95),
        1.0 - float(statutils.inverse_quantile(corrs_cause_only, corr_raw))
    ])
    db.execute('INSERT INTO surrogate_dist VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [cname, ename, 0] +
        numpy.percentile(corrs_cause_only, [0, 1, 2.5, 5, 25, 50, 75, 95, 97.5, 99, 100]).tolist()
    )
    
    # Run with cause and effect surrogates
    effect_mean, effect_anom = calculate_mean_anomaly(effect, 12)
    corrs_cause_and_effect = []
    for i in range(n_bootstraps):
        cause_surr = randomize_surrogate(cause_mean, cause_anom, rng)
        effect_surr = randomize_surrogate(effect_mean, effect_anom, rng)
        effect_surr_embedding = pyembedding.Embedding(effect_surr, delays)
        ccm_result, y_actual, y_pred = effect_surr_embedding.ccm(effect_surr_embedding, cause_surr, theiler_window=theiler_window)
        corrs_cause_and_effect.append(ccm_result['correlation'])
        #db.execute('INSERT INTO surrogate_corrs VALUES (?,?,?,?)', [cname, ename, 1, ccm_result['correlation']])
    db.execute('INSERT INTO surrogate_test VALUES (?,?,?,?,?,?)', [cname, ename, 1,
        corr_raw,
        numpy.percentile(corrs_cause_and_effect, 95),
        1.0 - float(statutils.inverse_quantile(corrs_cause_and_effect, corr_raw))
    ])
    db.execute('INSERT INTO surrogate_dist VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [cname, ename, 1] +
        numpy.percentile(corrs_cause_and_effect, [0, 1, 2.5, 5, 25, 50, 75, 95, 97.5, 99, 100]).tolist()
    )

def plot_timeseries(series, labels, xlabel, ylabel, filename):
    fig = pyplot.figure(figsize=(12,5))
    for x in series:
        pyplot.plot(x)
    pyplot.legend(labels)
    pyplot.xlabel(xlabel)
    pyplot.ylabel(ylabel)
    pyplot.savefig(filename)
    pyplot.close(fig)

def load_json(filename):
    with open(filename) as f:
        return json.load(f, object_pairs_hook=OrderedDict)

if __name__ == '__main__':
    main()
