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
    input_dir <- '../../in/ccm-analyses/transient'
    
    ts_plot <- plot_timeseries(input_dir)
    ggsave_pdf2svg('fig_transient_A', ts_plot, width=3, height=2)
    
    lagplot <- plot_ccm_bylag(input_dir)
    ggsave_pdf2svg('fig_transient_B', lagplot, width=6, height=5)
    
    html2pdf('fig_transient')
    
    invisible()
}

plot_timeseries <- function(input_dir)
{
    ts_mat <- load_json_matrix(file.path(input_dir, 'single-run', 'timeseries.json'))
    
    ts_df_C0 <- data.frame(t = (0:(nrow(ts_mat) - 1))/36, incidence = ts_mat[,1], variable = 'C0')
    ts_df_C1 <- data.frame(t = (0:(nrow(ts_mat) - 1))/36, incidence = ts_mat[,2], variable = 'C1')
    
    ts_df <- rbind(ts_df_C0, ts_df_C1)
    
    ggplot(data = ts_df, aes(x = t, y = incidence, colour = variable, linetype = variable)) +
        geom_line(aes(colour = variable)) +
        scale_colour_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        scale_linetype_discrete(name = 'variable', labels = c(expression(italic(C)[1]), expression(italic(C)[2]))) +
        labs(
            x = 'time (years)',
            y = 'monthly incidence'
        ) +
        theme_classic() +
        theme(
            legend.title=element_blank(),
            legend.position=c(0.9,0.5),
            plot.background = element_blank(),
            panel.background = element_blank(),
            legend.background = element_blank()
        )
}

plot_ccm_bylag <- function(input_dir)
{
    db <- dbConnect(SQLite(), file.path(input_dir, 'single-run', 'results.sqlite'))
    data_01 <- get_ccm_data_onedirection(db, 'C0', 'C1')
    data_10 <- get_ccm_data_onedirection(db, 'C1', 'C0')
    dbDisconnect(db)
    
    data_both <- rbind(data_01, data_10)
    
    ggplot(data = data_both, aes(x = delay, ymin = q2_5, ymax = q97_5, y = q50, colour = cause, linetype = cause)) +
        geom_ribbon(linetype = 0, fill = '#dddddd', show.legend=FALSE) +
        geom_line() +
        scale_y_continuous(limits=c(-0.25, 1)) +
        scale_colour_discrete(
            name = 'cause',
            labels = c(
                expression(italic(C)[1] * ' causes ' * italic(C)[2]),
                expression(italic(C)[2] * ' causes ' * italic(C)[1])
            )
        ) +
        scale_linetype_discrete(
            name = 'cause',
            labels = c(
                expression(italic(C)[1] * ' causes ' * italic(C)[2]),
                expression(italic(C)[2] * ' causes ' * italic(C)[1])
            )
        ) +
        labs(
            x = expression('cross-map lag'),
            y = expression('cross-map correlation ' * rho)
        ) +
        theme_classic() +
        theme(
            legend.title=element_blank(),
            legend.position=c(0.5, 0.08),
            legend.background=element_blank()
        )
}

get_ccm_data_onedirection <- function(db, cause, effect)
{
    df <- dbGetPreparedQuery(db,
        'SELECT cause, effect, delays, q50, q2_5, q97_5 FROM ccm_correlation_dist WHERE cause = ? AND effect = ? AND L > 100',
        data.frame(cause = cause, effect = effect)
    )
    
    df$delay <- vapply(
        df$delays,
        function(delays_str) {
            min(as.integer(strsplit(substr(delays_str, 2, nchar(delays_str) - 1), ', ')[[1]]))
        },
        1
    )
    
    return(df)
}

#     lags.append(lag)
#     medians.append(median)
#     q2_5s.append(q2_5)
#     q97_5s.append(q97_5)
#     
#     if len(lags) == 0:
#         return None
#     
#     return pyplot.errorbar(
#         lags, medians,
#         yerr=numpy.row_stack((numpy.array(q97_5s) - numpy.array(medians), numpy.array(medians) - numpy.array(q2_5s))),
#         label='{} causes {}'.format(cause, effect)
#     )

main()
