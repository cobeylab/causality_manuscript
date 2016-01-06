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
    ggsave('fig_detect_increase_A.svg', heatmap_plot, width=7, height=3)
    
    db <- dbConnect(SQLite(), '../../in/simulations/timeseries.sqlite')
    
    beta25_plot <- plot_timeseries_single(db, 4702)
    ggsave_pdf2svg('fig_detect_increase_B', beta25_plot, width=7, height=3)
    
    beta30_plot <- plot_timeseries_single(db, 6703)
    ggsave_pdf2svg('fig_detect_increase_C', beta30_plot, width=7, height=3)
    
    dbDisconnect(db)
    
    html2pdf('fig_detect_increase')
    
    invisible()
}

plot_heatmaps <- function()
{
    data_dir <- '../../in/ccm-analyses/1000y-monthly-incidence-untransformed/self-uniform'
    ccm_summ <- load_ccm_summary(data_dir)
    
    summ_seas_diff <- ccm_summ[
        ccm_summ$seasonal == 'seasonal' & ccm_summ$identical == 'different',
    ]
    summ_seas_diff$cause <- factor(summ_seas_diff$cause, levels=c('C1', 'C0'))
    
    cause_labeller <- function(variable, value) {
        ifelse(
            value == 'C0',
            expression(paste(italic(C)[1], ' drives ', italic(C)[2])),
            expression(paste(italic(C)[2], ' drives ', italic(C)[1]))
        )
    }
    
    ggplot(
        data = summ_seas_diff,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = increase_fraction)) +
        facet_grid(. ~ cause, labeller=cause_labeller) +
        labs(
            x = expression(paste('s.d. process noise (', italic(eta), ')')),
            y = expression(paste('cross-immunity (', italic(sigma)['12'], ')'))
        ) +
        heatmap_scale_fill() +
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
    ts_C0 <- data.frame(variable = 'C0', t = 1:nrow(ts), incidence = ts[,1])
    ts_C1 <- data.frame(variable = 'C1', t = 1:nrow(ts), incidence = ts[,2])
    
    ts_df <- rbind(ts_C0, ts_C1)
    print(head(ts_df))
    
    ggplot(data = ts_df, aes(x = t / 12, y = incidence, group = variable, colour = variable, linetype = variable)) +
        geom_line(size=0.4) +
        scale_colour_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        scale_linetype_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        labs(
            x = 'time (years)',
            y = 'monthly incidence'
        ) +
        theme_classic() +
        theme(legend.title=element_blank())
    
    #ggsave(filename, p, width=6, height=3)
}

main()
