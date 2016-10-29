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
library(grid)
library(gridExtra)
library(DBI)
library(RSQLite)
library(stats)

### EXTERNAL SOURCE ###

source('../../file_output.R')

main <- function()
{
    plot_timeseries(5, 'ts1.pdf')
    plot_timeseries(6, 'ts2.pdf')
    plot_phase()
    plot_correlation()
    plot_increase()
    plot_lag()
    
    #html2pdf('fig_conceptual')
        
    invisible()
}

plot_timeseries <- function(seed, filename)
{
    set.seed(seed)
    
    t0 <- 80
    tau = 15
    lag <- 20
    
    x <- rnorm(50, mean=0, sd=1)
    
    label_offset <- 2.0
    arrow_offset <- 0.8
    point_linetype <- 2
    
    df <- data.frame(t = 1:length(x), x = x)
    
    p_ts <- ggplot(data = df) +
        geom_line(aes(x = t, y = x)) +
        labs(
            x = NULL,
            y = NULL
        ) +
        theme_minimal() +
        theme(
            text = element_text(face = 'plain'),
            axis.line = element_blank(),
            axis.ticks = element_blank(),
            axis.text = element_blank(),
            axis.title = element_blank(),
            panel.margin = unit(0, 'npc'),
            panel.grid = element_blank(),
            plot.margin = unit(c(-0.5,-0.5,-0.5,-0.5), 'line'),
            panel.background = element_blank(),
            plot.background = element_blank()
        ) +
        scale_y_continuous(expand = c(0.4,0.4)) +
        scale_x_continuous(expand = c(0,0))
    ggsave(filename, p_ts, width=2.5, height=0.5)
}

plot_phase <- function()
{
    set.seed(5)
    
    x <- runif(50, -1, 1)
    y <- runif(50, -1, 1)
    df <- data.frame(x = x, y = y)
    
    d <- x*x + y*y
    indices <- sort(d, index.return = TRUE)$ix
    print(indices)
    
    p_phase <- ggplot(data = df) +
        geom_point(aes(x = x, y = y), colour = 'lightgray') +
        geom_point(x = 0, y = 0, colour = 'black', shape = 16, colour = 'black', size=3) +
        geom_point(x = x[indices[1]], y = y[indices[1]], shape = 16, colour = 'darkgray', size=3) +
        geom_point(x = x[indices[2]], y = y[indices[2]], shape = 16, colour = 'darkgray', size=3) +
        geom_point(x = x[indices[3]], y = y[indices[3]], shape = 16, colour = 'darkgray', size=3) +
        geom_point(x = x[indices[4]], y = y[indices[4]], shape = 16, colour = 'darkgray', size=3) +
#         geom_hline(yintercept = -0.3, colour='gray') +
#         geom_text(x = 0.9, y = -0.2, label = 'X(t)', parse = TRUE) +
#         geom_vline(xintercept = -0.3, colour='gray') +
#         geom_text(x = -0.05, y = 0.9, label = 'X(t - tau[1])', parse = TRUE) +
#         geom_abline(slope = 1, intercept = 0, colour='gray') +
#         geom_text(x = -0.7, y = -0.95, label = 'X(t - tau[2])', parse = TRUE) +
        lims(x = c(-1, 1), y = c(-1, 1)) +
        theme_classic() +
        theme(
            axis.line = element_blank(),
            axis.ticks = element_blank(),
            axis.text = element_blank(),
            axis.title = element_blank(),
            plot.background = element_blank(),
            panel.background = element_blank()
        )
    
    ggsave('phase.pdf', p_phase, width=2.0, height=1.25)
}

plot_correlation <- function()
{
    df <- data.frame(X = rnorm(1000, mean=0.0, sd=0.1))
    
    p_increase <- ggplot(data = df) +
        geom_density(linetype = 1, aes(x = X)) +
        labs(
            x = NULL,
            y = NULL
        ) +
        theme_classic() +
        theme(
            axis.text.y = element_blank(),
            axis.ticks.y = element_blank()
        )
    
    ggsave('correlation.pdf', p_increase, width=2.5, height=1.25)
}

plot_increase <- function()
{
    df <- data.frame(X = rnorm(1000, mean=0.0, sd=0.1), Y = rnorm(1000, mean=0.5, sd=0.2))
    
    p_increase <- ggplot(data = df) +
        geom_density(linetype = 1, aes(x = X)) +
        geom_density(linetype = 2, aes(x = Y)) + 
        labs(
            x = NULL,
            y = NULL
        ) +
        theme_classic() +
        theme(
            axis.text.y = element_blank(),
            axis.ticks.y = element_blank()
        )
    
    ggsave('increase.pdf', p_increase, width=2.5, height=1.25)
}

plot_lag <- function()
{
    xvals = seq(-20, 20, 0.1)
    
    df <- data.frame(
        X = xvals,
        Y = 10 * (dcauchy(xvals, location=-10.0, scale=5.0) + stats:::filter(rnorm(length(xvals), mean=0, sd=0.03), rep(1 / 40, 40))),
        Z = 10 * (dcauchy(xvals, location=5.0, scale=5.0) + stats:::filter(rnorm(length(xvals), mean=0, sd=0.03), rep(1 / 40, 40)))
    )
    
    errorY = 0.05 / (1 - df$Y)
    errorZ = 0.05 / (1 - df$Z)
    
    p_lag <- ggplot(data = df) +
        geom_ribbon(aes(x = X, ymin = Y - errorY, ymax = Y + errorY), fill = 'gray') +
        geom_ribbon(aes(x = X, ymin = Z - errorZ, ymax = Z + errorZ), fill = 'gray') +
        geom_line(linetype = 1, aes(x = X, y = Y)) +
        geom_line(linetype = 2, aes(x = X, y = Z)) +
        xlim(-20, 20) +
        
        theme_classic() +
        theme(
            axis.title = element_blank()
        )
    
    ggsave('lag.pdf', p_lag, width=2.5, height=1.25)
}

main()
