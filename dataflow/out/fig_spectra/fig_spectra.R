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
library(ggplot2)

### ANALYSIS SOURCES ###

source('../../transform_ccm_output.R')
source('../../in/spectral/analyze_spectra.R')
source('../../utils.R')

main <- function()
{
    spectra_dir <- '../../in/spectral/'
    
    spectral_data <- analyze_spectra(spectra_dir, '1000y-annual-incidence-untransformed', get_C_1000y_annual)
    ccm_data <- load_ccm_data('../../in/ccm-analyses/1000y-annual-incidence-untransformed/self-uniform')
    
    summ_C0_causes_C1 <- spectral_data[ccm_data$job_id + 1,]
    combined_data <- cbind(ccm_data, summ_C0_causes_C1)
    combined_data$seasonal <- factor(ifelse(combined_data$eps > 0, 'seasonal', 'nonseasonal'))
    combined_data$different <- factor(ifelse(combined_data$beta00 == 0.25, 'identical', 'different'))
    
    subdata <- combined_data[
        (combined_data$seasonal == 'nonseasonal') &
        (combined_data$different == 'identical') &
        (combined_data$cause == 'C0'),
    ]
    p <- ggplot(data = subdata, aes(x = xsdens_max, y = pvalue_increase, colour = factor(sd_proc), size = factor(sigma01))) +
        geom_point() +
        scale_size_discrete(range=c(1.0, 4.0)) +
        scale_colour_manual(values=c('#c7e9b4', '#7fcdbb', '#41b6c4', '#2c7fb8', '#253494')) +
        labs(
            x = 'maximum cross-spectral density',
            y = 'p-value for interaction',
            colour = expression(sigma[12]),
            size = expression(eta)
        ) +
        theme_classic()
    ggsave(p, filename='fig_spectra.pdf', width=6, height=4)
    
    xsdens_increase_cortest <- cor.test(subdata$xsdens_max, subdata$pvalue_increase)
    
    dump_lines(c(
        sprintf('\\newcommand{\\xsdens_pvalue_corr}{$%.2f$}', xsdens_increase_cortest$estimate),
        sprintf('\\newcommand{\\xsdens_pvalue_corr_pvalue}{$%.2g$}', xsdens_increase_cortest$p.value)
    ), 'spectra_results.tex')
    
    invisible()
}

main()
