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
source('../../file_output.R')
source('../../formatting.R')

main <- function()
{
    pA <- process_data(
        '../../in/ccm-analyses/100y-monthly-incidence-untransformed/self-nonuniform',
        'increase_fraction_self-nonuniform.pdf',
        'C0', 'seasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffembed_A', pA, width=6, height=2)
    
    pB <- process_data(
        '../../in/ccm-analyses/100y-monthly-incidence-untransformed/cross-projection',
        'increase_fraction_cross-projection.pdf',
        'C0', 'seasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffembed_B', pB, width=6, height=2)
    
    pC <- process_data(
        '../../in/ccm-analyses/100y-monthly-incidence-untransformed/cross-uniform',
        'increase_fraction_cross-uniform.pdf',
        'C0', 'seasonal', 'different'
    )
    ggsave_pdf2svg('fig_detect_diffembed_C', pC, width=6, height=2)
    
    html2pdf('fig_detect_diffembed')
    
    invisible()
}

process_data <- function(data_dir, plot_filename, var0_name, seasonal, identical)
{
    ccm_summ <- load_ccm_summary(data_dir)
    ccm_summ$qualitative <- make_qualitative(ccm_summ$increase_fraction)
    ccm_summ$increase_fraction_str <- sapply(ccm_summ$increase_fraction, function(x) { sprintf('%.2f', x) })
    
    summ_seas_diff <- ccm_summ[
        ccm_summ$seasonal == seasonal & ccm_summ$identical == identical,
    ]
    
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
    
    ggplot(
        data = summ_seas_diff,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = increase_fraction, linetype=qualitative, colour=qualitative, size=qualitative)) +
        geom_text(colour = 'lightgray', size=3, aes(label = increase_fraction_str)) +
        facet_grid(. ~ effect, labeller=effect_labeller) +
        labs(
            x = expression(paste('s.d. process noise (', italic(eta), ')')),
            y = expression(paste('cross-immunity (', italic(sigma)['12'], ')')),
            fill = 'causal fraction'
        ) +
        theme_classic() +
        theme(
            strip.background = element_blank(),
            legend.title = element_blank(),
            axis.text = element_text(size = 8),
            panel.margin = unit(0, 'in'),
            plot.margin = unit(c(0, 0, 0, 0.25), 'in')
        ) +
        heatmap_scale_fill() +
        scale_linetype_manual('', values=c(L1=1, L2=0, L3=2), guide=FALSE) +
        scale_colour_manual('', values=c(L1='black', L2=NA, L3='black'), guide=FALSE) +
        scale_size_manual('', values=c(L1=0.25, L2=0.0, L3=0.25), guide=FALSE)
}

main()
