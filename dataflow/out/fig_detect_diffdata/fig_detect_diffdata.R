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

source('../../transform_ccm_output.R')
source('../../formatting.R')
source('../../file_output.R')


main <- function()
{
    pA <- process_data(
        '../../in/ccm-analyses/1000y-annual-incidence-untransformed/self-uniform',
        'increase_fraction_seasonal_different_annual-incidence-untransformed.pdf',
        'C0', 'seasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffdata_A', pA, width=6, height=2)
    
    pB <- process_data(
        '../../in/ccm-analyses/1000y-annual-prevalence/self-uniform',
        'increase_fraction_seasonal_different_annual-prevalence.pdf',
        'logI0', 'seasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffdata_B', pB, width=6, height=2)
    
    pC <- process_data(
        '../../in/ccm-analyses/1000y-annual-incidence-firstdiff/self-uniform',
        'increase_fraction_seasonal_different_annual-incidence-firstdiff.pdf',
        'C0', 'seasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffdata_C', pC, width=6, height=2)
    
    pD <- process_data(
        '../../in/ccm-analyses/1000y-monthly-incidence-untransformed/self-uniform',
        'increase_fraction_nonseasonal_different_monthly-incidence-firstdiff.pdf',
        'C0', 'nonseasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffdata_D', pD, width=6, height=2)
    
    html2pdf('fig_detect_diffdata')
    
    invisible()
}

process_data <- function(data_dir, plot_filename, var0_name, seasonal, identical)
{
    ccm_summ <- load_ccm_summary(data_dir)
    
    summ_seas_diff <- ccm_summ[
        ccm_summ$seasonal == seasonal & ccm_summ$identical == identical,
    ]
    
    effect_labeller <- function(variable, value) {
        ifelse(
            value == var0_name,
            expression(paste(italic(C)[2], ' drives ', italic(C)[1])),
            expression(paste(italic(C)[1], ' drives ', italic(C)[2]))
        )
    }
    
    ggplot(
        data = summ_seas_diff,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = increase_fraction)) +
        facet_grid(. ~ effect, labeller=effect_labeller) +
        labs(
            x = expression(paste('s.d. process noise (', italic(eta), ')')),
            y = expression(paste('cross-immunity (', italic(sigma)['12'], ')'))
        ) +
        theme_classic() +
        theme(
            strip.background = element_blank(),
            legend.title = element_blank(),
            axis.text = element_text(size = 8)
        ) + 
        heatmap_scale_fill()
}

main()