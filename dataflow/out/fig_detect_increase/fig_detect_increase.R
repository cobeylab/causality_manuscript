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

library(gridExtra)
library(ggplot2)
library(DBI)
library(RSQLite)

### EXTERNAL SOURCE ###

source('../../transform_ccm_output.R')
source('../../load_timeseries.R')
source('../../formatting.R')
source('../../file_output.R')

main <- function()
{
    heatmap_plot <- plot_heatmaps()
    ggsave_pdf2svg('fig_detect_increase_A', heatmap_plot, width=6, height=2.5)
    
    db <- dbConnect(SQLite(), '../../in/simulations/timeseries.sqlite')
    
    beta25_plot <- plot_timeseries_single(db, 4702)
    ggsave_pdf2svg('fig_detect_increase_B', beta25_plot, width=6, height=2.5)
    
    beta30_plot <- plot_timeseries_single(db, 6703)
    ggsave_pdf2svg('fig_detect_increase_C', beta30_plot, width=6, height=2.5)
    
    dbDisconnect(db)
    
    html2pdf('fig_detect_increase')
    
    invisible()
}

plot_heatmaps <- function()
{
    data_dir <- '../../in/ccm-analyses/1000y-monthly-incidence-untransformed/self-uniform'
    ccm_summ <- load_ccm_summary(data_dir)
    ccm_summ$qualitative <- make_qualitative(ccm_summ$increase_fraction)
    
    summ_seas_diff <- ccm_summ[
        ccm_summ$seasonal == 'seasonal' & ccm_summ$identical == 'different',
    ]
    summ_seas_diff$cause <- factor(summ_seas_diff$cause, levels=c('C1', 'C0'))
    
    summ_seas_diff$increase_fraction_str <- sapply(
        summ_seas_diff$increase_fraction,
        function(x) { sprintf('%.2f', x) }
    )
    
    cause_labeller <- function(df) {
        result <- list()
        
        result[[1]] <- lapply(df$cause, function(x) {
                if(x == 'C0') {
                    return(expression(italic(C)[1] * ' causes ' * italic(C)[2]))
                }
                    return(expression(italic(C)[2] * ' causes ' * italic(C)[1]))
            }
        )
        
        return(result)
    }
    
    ggplot(
        data = summ_seas_diff,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = increase_fraction)) +
        geom_text(colour = 'lightgray', size = 3, aes(label = increase_fraction_str)) +
        facet_grid(. ~ cause, labeller=cause_labeller) +
        labs(
            x = expression(paste('s.d. process noise (', italic(eta), ')')),
            y = expression(paste('cross-immunity (', italic(sigma)['12'], ')'))
        ) +
        heatmap_scale_fill() +
        scale_linetype_manual('', values=c(L1=1, L2=0, L3=2), guide=FALSE) +
        scale_colour_manual('', values=c(L1='black', L2=NA, L3='black'), guide=FALSE) +
        scale_size_manual('', values=c(L1=0.25, L2=0.0, L3=0.25), guide=FALSE) +
        theme_classic() +
        theme(
            strip.background=element_blank(),
            legend.title = element_blank(),
            axis.text = element_text(size = 8)
        )
    
    #ggsave('increase_fraction_seasonal_different.pdf', p, width=6, height=3)
}

plot_timeseries_single <- function(db, job_id, filename)
{
    ts <- get_C_100y_monthly(load_timeseries(db, job_id))
    n_rows <- nrow(ts) / 4
    ts_C0 <- data.frame(variable = 'C0', t = 1:n_rows, incidence = ts[1:n_rows,1])
    ts_C1 <- data.frame(variable = 'C1', t = 1:n_rows, incidence = ts[1:n_rows,2])
    
    ts_df <- rbind(ts_C0, ts_C1)
    print(head(ts_df))
    
    ggplot(data = ts_df, aes(x = t / 12, y = incidence, group = variable, colour = variable)) +
        geom_line(size=0.4) +
        scale_colour_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        labs(
            x = 'time (years)',
            y = 'monthly incidence'
        ) +
        theme_classic() +
        theme(legend.title=element_blank())
    
    #ggsave(filename, p, width=6, height=3)
}

main()
