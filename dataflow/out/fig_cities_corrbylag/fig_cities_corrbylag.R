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

library(ggplot2)
library(tools)

### EXTERNAL SOURCE ###

main <- function()
{
    root_dir <- '../../in/ccm-analyses/cities'
    for(db_filename in c(
        'nyc_self_uniform.sqlite',
        'nyc_cross_projection.sqlite',
        'chi_self_uniform.sqlite',
        'chi_cross_projection.sqlite'
    )) {
        plot_db(file.path(root_dir, db_filename))
    }
    
    invisible()
}

plot_db <- function(db_filename)
{
    cat(sprintf('db_filename: %s\n', db_filename))
    db_filename_pieces <- strsplit(db_filename, '.', fixed=TRUE)[[1]]
    
    n_pieces = length(db_filename_pieces)
    path_base <- paste(db_filename_pieces[1:(n_pieces - 1)], collapse='.')
    
    path_pieces <- strsplit(db_filename, '/', fixed=TRUE)[[1]]
    filename_base <- strsplit(path_pieces[length(path_pieces)], '.', fixed=TRUE)[[1]][1]
    
    summ_filename <- paste(path_base, '_summ.Rds', sep='')
    print(summ_filename)
    if(file.exists(summ_filename)) {
        corrs_summ <- readRDS(summ_filename)
    }
    else {
        library(RSQLite)
        db <- dbConnect(SQLite(), db_filename)
        dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS correlations_index ON correlations (cause, effect, lag, L, correlation)')
        corrs_summ <- summarize(db)
        saveRDS(corrs_summ, summ_filename)
        dbDisconnect(db)
    }
    
    levels(corrs_summ$cause)[5] <- 'scarlet fever'
    levels(corrs_summ$effect)[5] <- 'scarlet fever'
    
    p <- ggplot(data=corrs_summ, aes(x=lag, y=med, ymin=q025, ymax=q975)) +
        geom_ribbon(colour='gray', size=0.1) +
        geom_line(size=0.1) +
        geom_vline(xintercept=0, linetype="dotted") +
        facet_grid(effect ~ cause, margins = FALSE, labeller = label_both) +
        labs(
            x = 'lag',
            y = expression('CCM '* rho)
        ) +
        theme(
            strip.background = element_blank()
        )
    
    plot_filename <- paste(filename_base, '_plot.pdf', sep='')
    print(plot_filename)
    ggsave(plot_filename, p, width=9, height=8)
}

summarize <- function(db)
{
    var_names <- dbGetQuery(db, 'SELECT DISTINCT cause FROM correlations')$cause
    lags <- dbGetQuery(db, 'SELECT DISTINCT lag FROM correlations ORDER BY lag')$lag
    
    summ <- as.data.frame(expand.grid(cause=var_names, effect=var_names, lag=lags))
    summ$med <- NA
    summ$q025 <- NA
    summ$q975 <- NA
    
    for(i in 1:nrow(summ)) {
        cause <- summ$cause[i]
        effect <- summ$effect[i]
        lag <- summ$lag[i]
        
        if(cause == effect) {
            next
        }
        
        max_L <- dbGetPreparedQuery(db,
            'SELECT max(L) AS L FROM correlations WHERE cause = ? AND effect = ? AND lag = ?',
            data.frame(cause=cause, effect=effect, lag=lag)
        )[1,1]
        
        if(is.na(max_L)) {
            next
        }
        
        corrs_i <- dbGetPreparedQuery(
            db,
            'SELECT correlation FROM correlations WHERE cause = ? AND effect = ? AND lag = ? AND L = ?',
            data.frame(cause=cause, effect=effect, lag=lag, L=max_L)
        )$correlation
        
        summ$med[i] <- median(corrs_i)
        summ$q025[i] <- quantile(corrs_i, probs=0.025)
        summ$q975[i] <- quantile(corrs_i, probs=0.975)
        
        #cat(sprintf('%s, %s, %d, %f, %f, %f\n', cause, effect, max_L, summ$med[i], summ$q025[i], summ$q975[i]))
    }
    
    return(summ)
}

main()
