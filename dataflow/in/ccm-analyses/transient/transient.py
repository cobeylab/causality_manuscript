#!/usr/bin/env python

import os
import sys
import json
import sqlite3
import numpy
import random
from collections import OrderedDict

import matplotlib
matplotlib.use('Agg')
from matplotlib import pyplot

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.append(os.path.join(SCRIPT_DIR, 'pyembedding'))

import pyembedding
import models
import statutils

def main():
    sysrng = random.SystemRandom()
    
    params = load_json(os.path.join(SCRIPT_DIR, 'transient.json'))
    params['random_seed'] = sysrng.randint(1, 2**31 - 1)
    
    S_init = [sysrng.random(), sysrng.random()]
    params['S_init'] = S_init
    I_init = [sysrng.uniform(0.0, S_init[0]), sysrng.uniform(0.0, S_init[1])]
    params['I_init'] = I_init
    
    ts_filename = 'transient.npy'
    if os.path.exists(ts_filename):
        C = numpy.load(ts_filename)
    else:
        sir_out = models.run_via_pypy('multistrain_sde', params)
        C = numpy.array(sir_out['C'])
        numpy.save(ts_filename, C)
     
    years = 100
    simulation_samples_per_year = 36
    ccm_samples_per_year = 12
    add_samples = True
    log_transform = False
    first_difference = False
    standardize = False
    
    # Connect to output database
    if os.path.exists('results.sqlite'):
        sys.stderr.write('Output database present. Aborting.\n')
        sys.exit(1)
    db = sqlite3.connect('results.sqlite')

    # Set up RNG
    rng = numpy.random.RandomState(sysrng.randint(1, 2**31 - 1))
    X = subsample_simulation(
        C, years, simulation_samples_per_year, ccm_samples_per_year,
        add_samples, log_transform, first_difference, standardize
    )
    
    if numpy.any(numpy.logical_or(
        numpy.isnan(X),
        numpy.isinf(X)
    )):
        sys.stderr.write('nans or infs in data; skipping all analyses.\n')
        sys.exit(0)
    
    x0 = X[:,0]
    x1 = X[:,1]

    variable_name = 'C'
    x0name = variable_name + '0'
    x1name = variable_name + '1'
    
    plot_timeseries([x0, x1], [x0name, x1name], 'time', 'value', 'timeseries.png')
    
    run_analysis(x0name, x0, x1name, x1, db, rng)
    run_analysis(x1name, x1, x0name, x0, db, rng)

    db.commit()
    db.close()
    
    plot_data_by_lag()

def load_json(filename):
    with open(filename) as f:
        return json.load(f, object_pairs_hook=OrderedDict)

def plot_timeseries(series, labels, xlabel, ylabel, filename):
    fig = pyplot.figure(figsize=(12,5))
    for x in series:
        pyplot.plot(x)
    pyplot.legend(labels)
    pyplot.xlabel(xlabel)
    pyplot.ylabel(ylabel)
    pyplot.savefig(filename)
    pyplot.close(fig)

def subsample_simulation(
    arr, years, simulation_samples_per_year, ccm_samples_per_year,
    add_samples, log_transform, first_difference, standardize
):
    # Get the unthinned sample from the end of the time series
    sim_samps_unthinned = years * simulation_samples_per_year
    thin = simulation_samples_per_year / ccm_samples_per_year
    arr_end_unthinned = arr[-sim_samps_unthinned:, :]
    
    # Thin the samples, adding in the intervening samples if requested
    arr_mod = arr_end_unthinned[::thin, :]
    if add_samples:
        for i in range(1, thin):
            arr_mod += arr_end_unthinned[i::thin, :]
    
    if log_transform:
        arr_mod = numpy.log(arr_mod)
    
    if first_difference:
        arr_mod = arr_mod[1:, :] - arr_mod[:-1, :]
    
    if standardize:
        for i in range(arr_mod.shape[1]):
            arr_mod[:,i] -= numpy.mean(arr_mod[:,i])
            arr_mod[:,i] /= numpy.std(arr_mod[:,i])


    if first_difference:
        assert arr_mod.shape[0] == years * ccm_samples_per_year - 1
    else:
        assert arr_mod.shape[0] == years * ccm_samples_per_year
    assert arr_mod.shape[1] == 2
    
    return arr_mod


def run_analysis(cname, cause, ename, effect, db, rng):
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
        theiler_window = 3 * ac_delay
        sys.stderr.write('  theiler_window = {0}\n'.format(theiler_window))
        assert theiler_window < effect.shape[0]
        
        run_analysis_max_univariate_prediction_plus_lags(cname, cause, ename, effect, theiler_window, db, rng)

def run_analysis_max_univariate_prediction_plus_lags(cname, cause, ename, effect, theiler_window, db, rng):
    delta_tau_termination = None
    
    max_corr = float('-inf')
    max_corr_Etau = None
    for E in range(1, 11):
        if delta_tau_termination is not None:
            max_corr_this_E = float('-inf')
            max_corr_tau_this_E = None
        
        for tau in (range(1, 61) if E > 1 else [1]):
            delays = tuple(range(0, E*tau, tau))
            embedding = pyembedding.Embedding(effect[:-1], delays)
            if embedding.delay_vector_count < embedding.embedding_dimension + 2:
                sys.stderr.write('  Lmax < Lmin; skipping E={}, tau={}\n'.format(E, tau))
                continue

            eff_off, eff_off_pred = embedding.simplex_predict_using_embedding(embedding, effect[1:], theiler_window=theiler_window)
            corr = numpy.corrcoef(eff_off, eff_off_pred)[0,1]

            db.execute('CREATE TABLE IF NOT EXISTS univariate_predictions (variable, E, tau, correlation)')
            db.execute('INSERT INTO univariate_predictions VALUES (?,?,?,?)', [ename, E, tau, corr])

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
    
    max_ccm_lag = 60
    
    best_lag_neg = None
    best_lag_neg_corr_med = None
    best_lag_neg_corrs = None
    best_lag_neg_pvalue_increase = None
    best_lag_neg_pvalue_positive = None
    
    best_lag_pos = None
    best_lag_pos_corr_med = None
    best_lag_pos_corrs = None
    best_lag_pos_pvalue_increase = None
    best_lag_pos_pvalue_positive = None
    
    zero_corrs = None
    zero_corr_med = None
    zero_pvalue_increase = None
    zero_pvalue_positive = None
    
    for lag in range(-max_ccm_lag, max_ccm_lag + 1):
        sys.stderr.write('  Using E = {}, tau = {}, lag = {}\n'.format(E, tau, lag))
        
        delays = tuple(range(lag, lag + E*tau, tau))
        max_corr_emb = pyembedding.Embedding(effect, delays)
        corrs, pvalue_increase, pvalue_positive = run_analysis_for_embedding(
            cname, cause, ename, effect, max_corr_emb, theiler_window, 100, db, rng
        )
        corr_med = numpy.median(corrs)
        
        if lag == 0:
            zero_corr_med = corr_med
            zero_corrs = corrs
            zero_pvalue_increase = pvalue_increase
            zero_pvalue_positive = pvalue_positive
        elif lag < 0 and (best_lag_neg is None or corr_med > best_lag_neg_corr_med):
            best_lag_neg = lag
            best_lag_neg_corr_med = corr_med
            best_lag_neg_corrs = corrs
            best_lag_neg_pvalue_increase = pvalue_increase
            best_lag_neg_pvalue_positive = pvalue_positive
        elif lag > 0 and (best_lag_pos is None or corr_med > best_lag_pos_corr_med):
            best_lag_pos = lag
            best_lag_pos_corr_med = corr_med
            best_lag_pos_corrs = corrs
            best_lag_pos_pvalue_increase = pvalue_increase
            best_lag_pos_pvalue_positive = pvalue_positive
    
    # Get the best negative-or-zero lag
    if best_lag_neg_corr_med > zero_corr_med:
        best_lag_nonpos = best_lag_neg
        best_lag_nonpos_corrs = best_lag_neg_corrs
        best_lag_nonpos_corr_med = best_lag_neg_corr_med
        best_lag_nonpos_pvalue_increase = best_lag_neg_pvalue_increase
        best_lag_nonpos_pvalue_positive = best_lag_neg_pvalue_positive
    else:
        best_lag_nonpos = 0
        best_lag_nonpos_corrs = zero_corrs
        best_lag_nonpos_corr_med = zero_corr_med
        best_lag_nonpos_pvalue_increase = zero_pvalue_increase
        best_lag_nonpos_pvalue_positive = zero_pvalue_positive
    
    # Get the best positive-or-zero lag
    if best_lag_pos_corr_med > zero_corr_med:
        best_lag_nonneg = best_lag_pos
        best_lag_nonneg_corrs = best_lag_pos_corrs
        best_lag_nonneg_corr_med = best_lag_pos_corr_med
        best_lag_nonneg_pvalue_increase = best_lag_pos_pvalue_increase
        best_lag_nonneg_pvalue_positive = best_lag_pos_pvalue_positive
    else:
        best_lag_nonneg = 0
        best_lag_nonneg_corrs = zero_corrs
        best_lag_nonneg_corr_med = zero_corr_med
        best_lag_nonneg_pvalue_increase = zero_pvalue_increase
        best_lag_nonneg_pvalue_positive = zero_pvalue_positive
    
    # Test if negative is better than nonnegative
    pvalue_neg_best = 1.0 - numpy.mean(statutils.inverse_quantile(best_lag_nonneg_corrs, best_lag_neg_corrs))
    
    # Test if nonpositive is better than positive
    pvalue_nonpos_best = 1.0 - numpy.mean(statutils.inverse_quantile(best_lag_pos_corrs, best_lag_nonpos_corrs))
    
    db.execute('''CREATE TABLE IF NOT EXISTS ccm_lag_tests (
        cause, effect,
        
        neg_lag,
        neg_corr_med,
        neg_pvalue_positive,
        neg_pvalue_increase,
        neg_pvalue_best,
        
        nonpos_lag,
        nonpos_corr_med,
        nonpos_pvalue_positive,
        nonpos_pvalue_increase,
        nonpos_pvalue_best,
        
        pos_lag,
        pos_corr_med,
        pos_pvalue_positive,
        pos_pvalue_increase,
        
        nonneg_lag,
        nonneg_corr_med,
        nonneg_pvalue_positive,
        nonneg_pvalue_increase
    )''')
    db.execute(
        'INSERT INTO ccm_lag_tests VALUES (?,?, ?,?,?,?,?, ?,?,?,?,?, ?,?,?,?, ?,?,?,?)',
        [
            cname, ename,
            
            best_lag_neg,
            best_lag_neg_corr_med,
            best_lag_neg_pvalue_positive,
            best_lag_neg_pvalue_increase,
            pvalue_neg_best,
            
            best_lag_nonpos,
            best_lag_nonpos_corr_med,
            best_lag_nonpos_pvalue_positive,
            best_lag_nonpos_pvalue_increase,
            pvalue_nonpos_best,
            
            best_lag_pos,
            best_lag_pos_corr_med,
            best_lag_pos_pvalue_positive,
            best_lag_pos_pvalue_increase,
            
            best_lag_nonneg,
            best_lag_nonneg_corr_med,
            best_lag_nonneg_pvalue_positive,
            best_lag_nonneg_pvalue_increase
        ]
    )


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
    
    pvalue_increase = 1.0 - numpy.mean(statutils.inverse_quantile(corrs_Lmin, corrs_Lmax))
    pvalue_positive = statutils.inverse_quantile(corrs_Lmax, 0.0).tolist()
    
    lag = embedding.delays[0]
    E = len(embedding.delays)
    if E == 1:
        tau = 1
    else:
        tau = embedding.delays[1] - embedding.delays[0]
    
    db.execute(
        'CREATE TABLE IF NOT EXISTS ccm_increase (cause, effect, Lmin, Lmax, E, tau, lag, pvalue_increase)'
    )
    db.execute(
        'INSERT INTO ccm_increase VALUES (?,?,?,?,?,?,?,?)',
        [
            cname, ename, Lmin, Lmax, E, tau, lag, pvalue_increase
        ]
    )
    db.commit()
    
    return corrs_Lmax, pvalue_increase, pvalue_positive

def run_ccm_bootstraps(cname, ename, embedding, cause, L, theiler_window, n_bootstraps, db, rng):
    assert isinstance(embedding, pyembedding.Embedding)

    corrs = []

    for i in range(n_bootstraps):
        sampled_embedding = embedding.sample_embedding(L, replace=True, rng=rng)
        ccm_result, y_actual, y_pred = sampled_embedding.ccm(embedding, cause, theiler_window=theiler_window)

        corrs.append(ccm_result['correlation'])

    corrs = numpy.array(corrs)
    pvalue_positive = statutils.inverse_quantile(corrs, 0.0).tolist()
    
    E = len(embedding.delays)
    if E == 1:
        tau = 1
    else:
        tau = embedding.delays[1] - embedding.delays[0]
    lag = embedding.delays[0]

    db.execute('CREATE TABLE IF NOT EXISTS ccm_correlation_dist (cause, effect, L, E, tau, lag, mean, sd, pvalue_positive, q0, q1, q2_5, q5, q25, q50, q75, q95, q97_5, q99, q100)')
    db.execute(
        'INSERT INTO ccm_correlation_dist VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [cname, ename, L, E, tau, lag, corrs.mean(), corrs.std(), pvalue_positive] +
            [x for x in numpy.percentile(corrs, [0, 1, 2.5, 5, 25, 50, 75, 95, 97.5, 99, 100])]
    )
    
    db.execute('CREATE TABLE IF NOT EXISTS ccm_correlations (cause, effect, L, E, tau, lag, correlation)')
    for corr in corrs:
        db.execute(
            'INSERT INTO ccm_correlations VALUES (?,?,?,?,?,?,?)',
            [cname, ename, L, E, tau, lag, corr]
    )

    return numpy.array(corrs)

def plot_data_by_lag():
    db = sqlite3.connect('results.sqlite')
    
    try:
        p1 = plot_data_by_lag_onedirection(db, 'C0', 'C1')
    except Exception as e:
        print e
        p1 = None
    
    try:
        p2 = plot_data_by_lag_onedirection(db, 'C1', 'C0')
    except:
        p2 = None
    
    pyplot.legend(handles=[x for x in [p1, p2] if x is not None])
    pyplot.savefig('ccm_lags.png')
    
    db.close()

def plot_data_by_lag_onedirection(db, cause, effect):
    lags = []
    medians = []
    q2_5s = []
    q97_5s = []
    
    for lag, median, q2_5, q97_5 in db.execute(
        'SELECT lag, q50, q2_5, q97_5 FROM ccm_correlation_dist WHERE cause = ? AND effect = ? AND L > 100',
        [cause, effect]
    ):
        lags.append(lag)
        medians.append(median)
        q2_5s.append(q2_5)
        q97_5s.append(q97_5)
    
    if len(lags) == 0:
        return None
    
    return pyplot.errorbar(
        lags, medians,
        yerr=numpy.row_stack((numpy.array(q97_5s) - numpy.array(medians), numpy.array(medians) - numpy.array(q2_5s))),
        label='{} causes {}'.format(cause, effect)
    )

if __name__ == '__main__':
    main()
