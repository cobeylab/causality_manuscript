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
load_ccm_data <- function(data_dir)
{
    db_path <- file.path(data_dir, 'results_gathered.sqlite')
    rds_path <- file.path(data_dir, 'ccm_data.Rds')
    
    if(file.exists(rds_path)) {
        return(readRDS(rds_path))
    }
    
    db <- dbConnect(SQLite(), db_path)
    
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS job_info_index ON job_info (job_id, eps, beta00, sigma01, sd_proc)')
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS ccm_increase_index ON ccm_increase (job_id, cause, effect)')
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS ccm_correlation_dist_index ON ccm_correlation_dist (job_id, cause, effect, L)')
    
    ccm_data <- dbGetQuery(db, 'SELECT * FROM ccm_increase ORDER BY job_id')
    
    ccm_data$eps <- NA
    ccm_data$beta00 <- NA
    ccm_data$sigma01 <- NA
    ccm_data$sd_proc <- NA
    
    ccm_data$mean <- NA
    ccm_data$sd <- NA
    ccm_data$q0 <- NA
    ccm_data$q1 <- NA
    ccm_data$q2_5 <- NA
    ccm_data$q5 <- NA
    ccm_data$q25 <- NA
    ccm_data$q50 <- NA
    ccm_data$q75 <- NA
    ccm_data$q95 <- NA
    ccm_data$q97_5 <- NA
    ccm_data$q99 <- NA
    ccm_data$q100 <- NA
    
    variable_names <- dbGetQuery(db, 'SELECT DISTINCT cause FROM ccm_increase ORDER BY cause')$cause
    
    for(i in 1:nrow(ccm_data)) {
        row_i <- ccm_data[i,]
        
        job_info <- dbGetPreparedQuery(
            db, 'SELECT * FROM job_info WHERE job_id = ?', data.frame(job_id = row_i$job_id)
        )
        for(colname in c('eps', 'beta00', 'sigma01', 'sd_proc')) {
            ccm_data[i,colname] <- job_info[colname]
        }
        
        ccm_corr_dist <- dbGetPreparedQuery(
            db, 'SELECT * FROM ccm_correlation_dist WHERE job_id = ? AND cause = ? AND effect = ? AND L = ?',
            data.frame(job_id = row_i$job_id, cause = row_i$cause, effect = row_i$effect, L = row_i$Lmax)
        )
        for(colname in c('pvalue_positive', 'mean', 'sd', 'q0', 'q1', 'q2_5', 'q5', 'q25', 'q50', 'q75', 'q95', 'q97_5', 'q99', 'q100')) {
            ccm_data[i, colname] <- ccm_corr_dist[colname]
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
load_ccm_summary <- function(data_dir, pvalue_threshold = 0.05)
{
    ccm_summary_path <- file.path(data_dir, sprintf('ccm_summary_%g.Rds', pvalue_threshold))
    if(file.exists(ccm_summary_path)) {
        return(readRDS(ccm_summary_path))
    }
    ccm_data <- load_ccm_data(data_dir)
    
    ccm_summ <- unique(ccm_data[c('eps', 'beta00', 'sigma01', 'sd_proc', 'cause', 'effect')])
    rownames(ccm_summ) <- NULL
    
    ccm_summ$pvalue_positive_mean <- NA
    ccm_summ$pvalue_positive_sd <- NA
    ccm_summ$positive_fraction <- NA
    
    for(i in 1:nrow(ccm_summ)) {
        summ_row <- ccm_summ[i,]
        ccm_data_subset <- ccm_data[
            ccm_data$eps == summ_row$eps &
            ccm_data$beta00 == summ_row$beta00 &
            ccm_data$sigma01 == summ_row$sigma01 &
            ccm_data$sd_proc == summ_row$sd_proc &
            ccm_data$cause == summ_row$cause &
            ccm_data$effect == summ_row$effect,
        ]
        
        ccm_summ[i, 'pvalue_positive_mean'] <- mean(ccm_data_subset$pvalue_positive, na.rm=T)
        ccm_summ[i, 'pvalue_positive_sd'] <- sd(ccm_data_subset$pvalue_positive, na.rm=T)
        ccm_summ[i, 'positive_fraction'] <- mean(ccm_data_subset$pvalue_positive < pvalue_threshold, na.rm=T)
        
        ccm_summ[i, 'pvalue_increase_mean'] <- mean(ccm_data_subset$pvalue_increase, na.rm=T)
        ccm_summ[i, 'pvalue_increase_sd'] <- sd(ccm_data_subset$pvalue_increase, na.rm=T)
        ccm_summ[i, 'increase_fraction'] <- mean(ccm_data_subset$pvalue_increase < pvalue_threshold, na.rm=T)
        
        ccm_summ[i, 'mean_mean'] <- mean(ccm_data_subset$mean, na.rm=T)
        ccm_summ[i, 'median_median'] <- median(ccm_data_subset$q50, na.rm=T)
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
