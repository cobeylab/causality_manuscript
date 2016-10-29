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
library(gridExtra)
library(DBI)
library(RSQLite)

### EXTERNAL SOURCES ###

source('../../utils.R')
source('../../file_output.R')

### MAIN PLOTTING FUNCTION ###

main <- function()
{
    input_dir <- '../../in/ccm-analyses/betachange/untransformed/jobs/00'
    
    for(segment in c('start', 'mid', 'end')) {
        ts_plot <- plot_timeseries(input_dir, segment, 'none')
        ggsave_pdf2svg(sprintf('ts_%s', segment), ts_plot, width = 6, height=2)
    }
    ts_plot_for_legend <- plot_timeseries(input_dir, segment, 'top')
    ggsave_pdf2svg(sprintf('ts_for_legend', 'start'), ts_plot_for_legend, width=6, height=2)
    html2pdf('fig_betachange')
    
    invisible()
}

plot_timeseries <- function(input_dir, segment, legend_position)
{
    ts_mat <- load_json_matrix(file.path(input_dir, sprintf('ts_%s.json', segment)))
    
    ts_df_C0 <- data.frame(t = (0:(nrow(ts_mat) - 1))/12, incidence = ts_mat[,1], variable = 'C0')
    ts_df_C1 <- data.frame(t = (0:(nrow(ts_mat) - 1))/12, incidence = ts_mat[,2], variable = 'C1')
    
    ts_df <- rbind(ts_df_C0, ts_df_C1)
    
    ggplot(data = ts_df, aes(x = t, y = incidence, colour = variable, linetype = variable)) +
        geom_line(aes(colour = variable), size = 0.3) +
        scale_y_continuous(limits = c(0, 0.025)) +
        scale_x_continuous(limits = c(0, 100)) +
        scale_colour_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        scale_linetype_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        labs(
            x = 'time (years)',
            y = 'monthly incidence'
        ) +
        theme_classic() +
        theme(
            legend.title=element_blank(),
            plot.background = element_blank(),
            panel.background = element_blank(),
            legend.background = element_blank(),
            legend.position = legend_position,
            plot.margin = unit(c(0.3, 0, 0, 0.4), 'cm')
        )
}

main()
