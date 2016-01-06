#!/usr/bin/env Rscript

### BOILERPLATE TO CHDIR TO THIS SCRIPT'S DIRECTORY ###

get_script_dir <- function()
{
    command_args <- commandArgs(trailingOnly = FALSE)
    file_arg_name <- '--file='
    tools:::file_path_as_absolute(
        dirname(
            sub(file_arg_name, '', command_args[grep(file_arg_name, command_args)])
        )
    )
}

setwd(get_script_dir())

### LIBRARIES ###

library(RSQLite)
# library(ggplot2)

#main <- function()
#{
#     ccm_data <- readRDS('/Users/ebaskerv/uchicago/midway_cobey/ccmproject-storage/2015-11-23-everything/1000y-annual/univariate-tausearch/ccm_data.rds')
#     
#    db <- dbConnect(SQLite(), '../simulations/timeseries.sqlite')
    #results <- analyze_spectra(db, 'C_1000y_annual', get_C_1000y_annual, 100)
    #results <- analyze_spectra(db, 'C_100y_monthly', get_C_100y_monthly, 100)
#    results <- analyze_spectra(db, 'C_1000y_monthly', get_C_1000y_monthly, 100)
    
#    dbDisconnect(db)
#     
#     summ_C0_causes_C1 <- results$summ[ccm_data$job_id + 1,]
#     
#     combined_data <- cbind(ccm_data, summ_C0_causes_C1)
#     combined_data$seasonal <- factor(ifelse(combined_data$eps > 0, 'seasonal', 'nonseasonal'))
#     combined_data$different <- factor(ifelse(combined_data$beta00 == 0.25, 'identical', 'different'))
    
#     do_scatterplot <- function(x, y, filename) {
#         for(seasonal in c('seasonal', 'nonseasonal')) {
#             for(different in c('identical', 'different')) {
#                 for(cause in c('C0', 'C1')) {
#                     effect = ifelse(cause == 'C0', 'C1', 'C0')
#                     
#                     if(!file.exists('scatterplots')) {
#                         dir.create('scatterplots')
#                     }
#                     subdata <- combined_data[(combined_data$seasonal == seasonal) & (combined_data$different == different) & (combined_data$cause == cause),]
#                     p <- eval(substitute(
#                         qplot(x, y, colour = sigma01, size = log(sd_proc),
#                             data = subdata,
#                         ) + scale_size(range = c(0.2, 5))
#                     ))
#                     ggsave(p, filename=file.path('scatterplots', sprintf('%s-%s-%s-%s-causes-%s.png', filename, seasonal, different, cause, effect)))
#                 }
#             }
#         }
#     }
#     
#     do_scatterplot(xsdens_max, pvalue_increase, 'xsdens_increase')
#     do_scatterplot(xsdens_max, pvalue_positive, 'xsdens_positive')
#     do_scatterplot(xsdens_argmax, pvalue_increase, 'freq_xsdens_increase')
#     do_scatterplot(xsdens_argmax, pvalue_positive, 'freq_xsdens_positive')
#     
#     do_scatterplot(coh_max, pvalue_increase, 'coh_increase')
#     do_scatterplot(coh_max, pvalue_positive, 'coh_positive')
#     do_scatterplot(coh_argmax, pvalue_increase, 'freq_coh_increase')
#     do_scatterplot(coh_argmax, pvalue_positive, 'freq_coh_positive')
#     
#     do_scatterplot(xcorr_max, pvalue_increase, 'xcorr_increase')
#     do_scatterplot(xcorr_max, pvalue_positive, 'xcorr_positive')
#     do_scatterplot(xcorr_argmax, pvalue_increase, 'lag_xcorr_increase')
#     do_scatterplot(xcorr_argmax, pvalue_positive, 'lag_xcorr_positive')
#     
#     do_scatterplot(sigma01, pvalue_increase, 'sigma01_increase')
#     do_scatterplot(sigma01, pvalue_positive, 'sigma01_positive')
#     
#     do_scatterplot(sd_proc, pvalue_increase, 'sd_proc_increase')
#     do_scatterplot(sd_proc, pvalue_positive, 'sd_proc_positive')
 #    
#     invisible()
# }

analyze_spectra <- function(spectra_dir, data_name, extract_func, n_reps)
{
    results_file_path <- file.path(spectra_dir, sprintf('spectra-%s.Rds', data_name))
    if(file.exists(results_file_path)) {
        return(readRDS(results_file_path))
    }
    
#     plots_dir <- sprintf('%s-individual-plots', data_name)
    
    db <- dbConnect(SQLite(), file.path(spectra_dir, '../simulations/timeseries.sqlite'))
    
    job_info <- load_job_info(db)
    
    summ <- data.frame(job_info)
    summ$coh_max <- NA
    summ$coh_argmax <- NA
    summ$xsdens_max <- NA
    summ$xsdens_argmax <- NA
    summ$xcorr_max <- NA
    summ$xcorr_argmax <- NA
    
#     spec_list <- list()
#     corrs_list <- list()
#     xspec_list <- list()
    
    for(i in 1:nrow(job_info)) {
        if((i-1) %% 100 >= n_reps) next
        
        job_id <- job_info$job_id[i]
        print(job_id)
        timeseries <- extract_func(load_timeseries(db, job_id))
        
        # Normalize
        timeseries[,1] <- (timeseries[,1] - mean(timeseries[,1])) / sd(timeseries[,1])
        timeseries[,2] <- (timeseries[,2] - mean(timeseries[,2])) / sd(timeseries[,2])
        
        colnames(timeseries) <- c('C0', 'C1')
        
#         spec_list[[i]] <- tryCatch(spectrum(timeseries, spans=5, plot=F), error = function(e) NA)
        spec <- tryCatch(spectrum(timeseries, spans=5, plot=F), error = function(e) NA)
        if(!is.na(spec)) {
            summ$coh_max[i] <- max(spec$coh)
            summ$coh_argmax[i] <- spec$freq[which.max(spec$coh)]
        }
        
        # corrs_list[[i]] <- tryCatch(acf(timeseries, type='correlation', plot=F), error = function(e) NA)
        xcorrs <- tryCatch(acf(timeseries, type='correlation', plot=F), error = function(e) NA)
        if(!is.na(xcorrs)) {
            ccfts <- ccf(timeseries[,1], timeseries[,2])
            summ$xcorr_max[i] <- max(ccfts$acf[,,1])
            summ$xcorr_argmax[i] <- ccfts$lag[,,1][which.max(ccfts$acf[,,1])]
        }
        
#         xspec_list[[i]] <- tryCatch(spectrum(ccf(timeseries[,1], timeseries[,2], plot=F)$acf[,,1], spans=5, plot=F), error = function(e) NA)
        xspec <- tryCatch(spectrum(ccf(timeseries[,1], timeseries[,2], plot=F)$acf[,,1], spans=5, plot=F), error = function(e) NA)
        if(!is.na(xspec)) {
            summ$xsdens_max[i] <- max(xspec$spec)
            summ$xsdens_argmax[i] <- xspec$freq[which.max(xspec$spec)]
        }
    }
    
#     results <- list(
#         job_info = job_info,
#         summ = summ,
#         spec = spec_list,
#         xspec = xspec_list,
#         corrs = corrs_list
#     )
#     
#     saveRDS(
#         results,
#         file=results_file_path
#     )
    
    saveRDS(summ, file=results_file_path)
}

load_job_info <- function(db)
{
    dbGetQuery(db, 'SELECT * FROM job_info ORDER BY job_id')
}

get_job_ids <- function(db)
{
    dbGetQuery(db, 'SELECT job_id FROM job_info ORDER BY job_id')$job_id
}

load_timeseries <- function(db, job_id)
{
    dbGetPreparedQuery(
        db, 
        'SELECT logI0, logI1, C0, C1 FROM timeseries WHERE job_id = ? ORDER BY ind',
        data.frame(job_id = job_id)
    )
}

get_C_1000y_monthly <- function(timeseries)
{
    return(timeseries[,c('C0', 'C1')])
}

get_C_100y_monthly <- function(timeseries)
{
    N <- nrow(timeseries)
    return(timeseries[(N - 100 * 12 + 1):N, c('C0', 'C1')])
}


get_C_1000y_annual <- function(timeseries)
{
    monthly <- get_C_1000y_monthly(timeseries)
    annual <- matrix(nrow=1000, ncol=2)
    for(i in 1:1000) {
        start <- 12 * (i-1) + 1
        annual[i,] <- apply(monthly[start:(start+11),], 2, sum)
    }
    return(annual)
}

get_C_1000y_annual_fd <- function(timeseries)
{
    nofd <- get_C_1000y_annual(timeseries)
    nofd[2:nrow(nofd),] - nofd[1:(nrow(nofd)-1),]
}

get_C_1000y_annual_log_fd <- function(timeseries)
{
    nofd <- log(get_C_1000y_annual(timeseries))
    nofd[2:nrow(nofd),] - nofd[1:(nrow(nofd)-1),]
}

get_C_1000y_biennial <- function(timeseries)
{
    monthly <- get_C_1000y_monthly(timeseries)
    biennial <- matrix(nrow=500, ncol=2)
    for(i in 1:500) {
        start <- 24 * (i-1) + 1
        biennial[i,] <- apply(monthly[start:(start+23),], 2, sum)
    }
    return(biennial)
}

get_I_1000y_monthly <- function(timeseries)
{
    return(exp(timeseries[,c('logI0', 'logI1')]))
}

get_I_1000y_annual <- function(timeseries)
{
    monthly <- get_I_1000y_monthly(timeseries)
    annual <- matrix(nrow=1000, ncol=2)
    for(i in 1:1000) {
        annual[i,] <- monthly[12 * (i-1) + 4,] # offset by 3 months to yield point of max beta
    }
    return(annual)
}
