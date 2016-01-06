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

### EXTERNAL SOURCE ###

source('../../transform_ccm_output_lagtest.R')
source('../../formatting.R')

main <- function()
{
    data_dir <- '../../in/ccm-analyses/100y-monthly-incidence-untransformed/self-uniform-lagtest'
    ccm_summ <- load_ccm_summary_lagtest(data_dir)
    
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
    
    p <- ggplot(
        data = summ_seas_diff,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = frac_neg_rhopos_and_best)) +
        facet_grid(. ~ cause, labeller=cause_labeller) +
        labs(
            x = expression(paste('s.d. process noise (', italic(eta), ')')),
            y = expression(paste('cross-immunity (', italic(sigma)['12'], ')')),
            fill = 'causal fraction'
        ) +
        theme_classic() +
        theme(
            strip.background = element_blank(),
            legend.title = element_blank()
        ) +
        heatmap_scale_fill()
    
    ggsave('fig_detect_lag.pdf', p, width=6, height=3)
}

main()
