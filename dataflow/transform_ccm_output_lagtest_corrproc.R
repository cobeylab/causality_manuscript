#!/usr/bin/env Rscript

library(DBI)
library(RSQLite)

# Constructs a data frame, one row per simulation:
# eps
# beta00
# sigma01
# sd_proc
# replicate_id
# Lmin
# Lmax
# delays
# pvalue_positive
# pvalue_increase
# mean
# sd
# q0
# q1
# q2_5
# q5
# q25
# q50
# q75
# q95
# q97_5
# q99
# q100
load_ccm_data_lagtest <- function(data_dir)
{
    db_path <- file.path(data_dir, 'results_gathered.sqlite')
    rds_path <- file.path(data_dir, 'ccm_data.Rds')
    
    if(file.exists(rds_path)) {
        return(readRDS(rds_path))
    }
    
    db <- dbConnect(SQLite(), db_path)
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS job_info_index ON job_info (job_id, eps, beta00, sigma01, sd_proc, corr_proc)')
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS ccm_lag_tests_index ON ccm_lag_tests (job_id, cause, effect)')
    
    ccm_data <- dbGetQuery(db, 'SELECT * FROM ccm_lag_tests ORDER BY job_id')
    variable_names <- dbGetQuery(db, 'SELECT DISTINCT cause FROM ccm_lag_tests ORDER BY cause')$cause
    
    for(i in 1:nrow(ccm_data)) {
        row_i <- ccm_data[i,]
        
        job_info <- dbGetPreparedQuery(
            db, 'SELECT * FROM job_info WHERE job_id = ?', data.frame(job_id = row_i$job_id)
        )
        for(colname in c('eps', 'beta00', 'sigma01', 'sd_proc', 'corr_proc')) {
            ccm_data[i,colname] <- job_info[colname]
        }
    }
    
    dbDisconnect(db)
    
    saveRDS(ccm_data, file = rds_path)
    return(ccm_data)
}

# Constructs a summarized data frame with columns:
# eps
# beta00
# sigma01
# sd_proc
# cause
# effect
# pvalue_positive_mean
# pvalue_positive_sd
# positive_fraction
# pvalue_increase_mean
# pvalue_increase_sd
# increase_fraction
# mean_mean
# median_median
load_ccm_summary_lagtest <- function(data_dir, pvalue_threshold = 0.05)
{
    ccm_summary_path <- file.path(data_dir, sprintf('ccm_summary_%g.Rds', pvalue_threshold))
    if(file.exists(ccm_summary_path)) {
        return(readRDS(ccm_summary_path))
    }
    
    ccm_data <- load_ccm_data_lagtest(data_dir)
    ccm_summ <- unique(ccm_data[c('eps', 'beta00', 'sigma01', 'sd_proc', 'corr_proc', 'cause', 'effect')])
    rownames(ccm_summ) <- NULL
    
    for(i in 1:nrow(ccm_summ)) {
        summ_row <- ccm_summ[i,]
        ccm_data_subset <- ccm_data[
            ccm_data$eps == summ_row$eps &
            ccm_data$beta00 == summ_row$beta00 &
            ccm_data$sigma01 == summ_row$sigma01 &
            ccm_data$sd_proc == summ_row$sd_proc &
            ccm_data$corr_proc == summ_row$corr_proc &
            ccm_data$cause == summ_row$cause &
            ccm_data$effect == summ_row$effect,
        ]
        
        neg_pvalue_increase <- ccm_data_subset$neg_pvalue_increase < 0.05
        neg_pvalue_positive <- ccm_data_subset$neg_pvalue_positive < 0.05
        neg_pvalue_best <- ccm_data_subset$neg_pvalue_best < 0.05
        neg_pvalue_mean_best <- ccm_data_subset$neg_pvalue_mean_best < 0.05
        
        ccm_summ[i, 'frac_neg_rhoinc'] <- mean(neg_pvalue_increase)
        ccm_summ[i, 'frac_neg_rhopos'] <- mean(neg_pvalue_positive)
        ccm_summ[i, 'frac_neg_best'] <- mean(neg_pvalue_best)
        ccm_summ[i, 'frac_neg_rhoinc_and_best'] <- mean(neg_pvalue_positive & neg_pvalue_increase & neg_pvalue_best)
        ccm_summ[i, 'frac_neg_rhopos_and_best'] <- mean(neg_pvalue_positive & neg_pvalue_best)
        ccm_summ[i, 'frac_neg_rhoinc_and_mean_best'] <- mean(neg_pvalue_positive & neg_pvalue_increase & neg_pvalue_mean_best)
        ccm_summ[i, 'frac_neg_rhopos_and_mean_best'] <- mean(neg_pvalue_positive & neg_pvalue_mean_best)
        
        nonpos_pvalue_increase <- ccm_data_subset$nonpos_pvalue_increase < 0.05
        nonpos_pvalue_positive <- ccm_data_subset$nonpos_pvalue_positive < 0.05
        nonpos_pvalue_best <- ccm_data_subset$nonpos_pvalue_best < 0.05
        nonpos_pvalue_mean_best <- ccm_data_subset$nonpos_pvalue_mean_best < 0.05
        
        ccm_summ[i, 'frac_nonpos_rhoinc'] <- mean(nonpos_pvalue_increase)
        ccm_summ[i, 'frac_nonpos_rhopos'] <- mean(nonpos_pvalue_positive)
        ccm_summ[i, 'frac_nonpos_best'] <- mean(nonpos_pvalue_best)
        ccm_summ[i, 'frac_nonpos_rhoinc_and_best'] <- mean(nonpos_pvalue_positive & nonpos_pvalue_increase & nonpos_pvalue_best)
        ccm_summ[i, 'frac_nonpos_rhopos_and_best'] <- mean(nonpos_pvalue_positive & nonpos_pvalue_best)
        ccm_summ[i, 'frac_nonpos_rhoinc_and_mean_best'] <- mean(nonpos_pvalue_positive & nonpos_pvalue_increase & nonpos_pvalue_mean_best)
        ccm_summ[i, 'frac_nonpos_rhopos_and_mean_best'] <- mean(nonpos_pvalue_positive & nonpos_pvalue_mean_best)
    }
    
    ccm_summ$seasonal <- factor(NA, levels = c('nonseasonal', 'seasonal'))
    ccm_summ[ccm_summ$eps == 0.0, 'seasonal'] <- 'nonseasonal'
    ccm_summ[ccm_summ$eps == 0.1, 'seasonal'] <- 'seasonal'
    
    ccm_summ$identical <- factor(NA, levels = c('identical', 'different'))
    ccm_summ[ccm_summ$beta00 == 0.25, 'identical'] <- 'identical'
    ccm_summ[ccm_summ$beta00 == 0.30, 'identical'] <- 'different'
    
    saveRDS(ccm_summ, file=ccm_summary_path)
    return(ccm_summ)
}
