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

source('../../transform_ccm_output_lagtest_corrproc.R')
source('../../formatting.R')

main <- function()
{
    process_data(
        '../../in/ccm-analyses/100y-monthly-incidence-untransformed-corrproc/different',
        'fig_detect_corrproc_distinct.pdf',
        'frac_neg_rhopos_and_best'
    )
}
    
    
    
process_data <- function(data_dir, plot_filename, test_name)
{
    ccm_summ <- load_ccm_summary_lagtest(data_dir)
    
    effect_labeller <- function(variable, value) {
        ifelse(
            value == 'C0',
            expression(paste(italic(C)[2], ' drives ', italic(C)[1])),
            expression(paste(italic(C)[1], ' drives ', italic(C)[2]))
        )
    }
    
    p <- ggplot(
        data = ccm_summ,
        aes(x = factor(sd_proc), y = factor(corr_proc))
    ) +
        geom_tile(aes_string(fill = test_name)) +
        facet_grid(. ~ effect, labeller=effect_labeller) +
        labs(
            x = expression(paste('s.d. process noise (', italic(eta), ')')),
            y = 'noise correlation',
            fill = 'causal fraction'
        ) +
        heatmap_scale_fill() +
        theme_classic() +
        theme(
            strip.background = element_blank(),
            legend.title = element_blank()
        )
    
    ggsave(plot_filename, p, width=5, height=3)
}

main()
