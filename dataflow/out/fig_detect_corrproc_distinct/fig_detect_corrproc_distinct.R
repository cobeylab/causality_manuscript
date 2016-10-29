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

source('../../file_output.R')
source('../../transform_ccm_output_lagtest_corrproc.R')
source('../../formatting.R')

main <- function()
{
    combined_data <- combine_data(
        '../../in/ccm-analyses/100y-monthly-incidence-untransformed-corrproc',
        c('different-5y', 'different-10y', 'different-25y', 'different-50y', 'different'),
        c(5, 10, 25, 50, 100)
    )
    process_data(combined_data, 'fig_detect_corrproc_distinct', 'frac_neg_rhopos_and_best')
}

combine_data <- function(basedir, subdirs, years)
{
    ccm_summ_combined <- NULL
    for(i in 1:length(subdirs)) {
        data_dir <- file.path(basedir, subdirs[i])
        ccm_summ <- load_ccm_summary_lagtest(data_dir)
        ccm_summ$years <- years[i]
        
        if(is.null(ccm_summ_combined)) {
            ccm_summ_combined <- ccm_summ
        }
        else {
            ccm_summ_combined <- rbind(ccm_summ_combined, ccm_summ)
        }
    }
    return(ccm_summ_combined)
}
    
process_data <- function(ccm_summ, plot_filename, test_name)
{
    effect_labeller <- function(df) {
        result <- list()
        
        result[[1]] <- lapply(df$effect, function(x) {
                if(x == 'C1') {
                    return(expression(italic(C)[1] * ' causes ' * italic(C)[2]))
                }
                return(expression(italic(C)[2] * ' causes ' * italic(C)[1]))
            }
        )
        
        return(result)
    }
    
    test_str_name <- sprintf('%s_str', test_name)
    ccm_summ[,test_str_name] <- sapply(ccm_summ[,test_name], function(x) { sprintf('%.2f', x) })
    
    p <- ggplot(
        data = ccm_summ,
        aes(x = factor(years), y = factor(corr_proc))
    ) +
        geom_tile(aes_string(fill = test_name)) +
        geom_text(colour = 'lightgray', size=3, aes_string(label = test_str_name)) +
        facet_grid(. ~ effect, labeller=effect_labeller) +
        labs(
            x = 'time series length (years)',
            y = 'noise correlation',
            fill = 'causal fraction'
        ) +
        heatmap_scale_fill() +
        scale_linetype_manual('', values=c(L1=1, L2=0, L3=2), guide=FALSE) +
        scale_colour_manual('', values=c(L1='black', L2=NA, L3='black'), guide=FALSE) +
        scale_size_manual('', values=c(L1=0.25, L2=0.0, L3=0.25), guide=FALSE) +
        theme_classic() +
        theme(
            strip.background = element_blank(),
            legend.title = element_blank(),
            panel.margin = unit(0.2, 'in'),
            plot.margin = unit(c(0, 0, 0, 0.0), 'in'),
            axis.text = element_text(size=10),
            axis.title = element_text(size=10)
        )
    
    #ggsave_pdf2svg(plot_filename, p, width=6, height=2)
    #html2pdf(plot_filename)
    ggsave(sprintf('%s.pdf', plot_filename), p, width=6, height=2)
}

main()
