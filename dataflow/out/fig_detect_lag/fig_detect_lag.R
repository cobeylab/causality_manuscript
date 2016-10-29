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
source('../../file_output.R')

main <- function()
{
    data_dir <- '../../in/ccm-analyses/100y-monthly-incidence-untransformed/self-uniform-lagtest'
    ccm_summ <- load_ccm_summary_lagtest(data_dir)
    
    summ_seas_diff <- ccm_summ[
        ccm_summ$seasonal == 'seasonal' & ccm_summ$identical == 'different',
    ]
    summ_seas_diff$cause <- factor(summ_seas_diff$cause, levels=c('C1', 'C0'))
    summ_seas_diff$qualitative <- make_qualitative(summ_seas_diff$frac_neg_rhopos_and_best)
    
    summ_seas_diff$frac_neg_rhopos_and_best_str <- sapply(
        summ_seas_diff$frac_neg_rhopos_and_best,
        function(x) {
            sprintf('%.2f', x)
        }
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
    
    p <- ggplot(
        data = summ_seas_diff,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = frac_neg_rhopos_and_best)) +
        geom_text(colour = 'lightgray', size = 3, aes(label = frac_neg_rhopos_and_best_str)) +
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
        heatmap_scale_fill() +
        scale_colour_manual('', values=c('black', NA, 'black'), guide=FALSE)
    
    ggsave_pdf2svg('fig_detect_lag', p, width=6, height=3)
    html2pdf('fig_detect_lag')
}

main()
