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

### EXTERNAL SOURCE ###

source('../../file_output.R')
source('../../formatting.R')

main <- function()
{
    input_dir <- '../../in/ccm-analyses/cities'
    
    nyc_ts_plot <- plot_timeseries(file.path(input_dir, 'NYC_inc_no_nonstationary.csv'))
    ggsave_pdf2svg('fig_cities_A', nyc_ts_plot, width=10, height=3)
    
    chi_ts_plot <- plot_timeseries(file.path(input_dir, 'chicago_inc.csv'))
    ggsave_pdf2svg('fig_cities_B', chi_ts_plot, width=10, height=3)
    
    su_plot <- plot_network('networks.sqlite', 'edges', 'self_uniform')
    ggsave_pdf2svg('fig_cities_C', su_plot, width=5, height=5)
    
    cp_plot <- plot_network('networks.sqlite', 'edges', 'cross_projection')
    ggsave_pdf2svg('fig_cities_D', cp_plot, width=5, height=5)
    
    html2pdf('fig_cities')
    
    invisible()
}

plot_timeseries <- function(input_filename)
{
    ts_bycol <- read.csv(input_filename)
    ts_dfs <- list()
    for(i in 1:ncol(ts_bycol)) {
        ts_dfs[[i]] <- data.frame(t=1:nrow(ts_bycol), value=ts_bycol[,i], disease=colnames(ts_bycol)[i])
    }
    ts_df <- do.call(rbind, ts_dfs)
    
    p <- ggplot(data=ts_df, aes(x = (1906 + t / 52), y = value, colour = disease)) +
        geom_line(aes(colour=disease), size=0.2) +
        labs(
            y = 'weekly incidence per 1000'
        ) +
        theme_classic() +
        theme(
            legend.title = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_text(size = 10)
        )
}

plot_network <- function(db_filename, edges_table_name, embedding_method)
{
    node_names <- c('varicella', 'measles', 'mumps', 'polio', 'scarlet fever', 'pertussis')
    n <- length(node_names)
    angles <- 0.5 * pi - (0:(n-1)) * 2 * pi / n
    nodes <- data.frame(
        name = node_names,
        x = cos(angles),
        y = sin(angles)
    )
    node_index <- function(node) which(nodes == node)
    
    db <- dbConnect(SQLite(), db_filename)
    edges <- dbGetQuery(db, sprintf('SELECT * FROM %s', edges_table_name))
    dbDisconnect(db)
    
    edges <- edges[edges$embedding_method == embedding_method,]
    
    edges$cause_index <- vapply(edges$cause, node_index, 1)
    edges$effect_index <- vapply(edges$effect, node_index, 1)
    
    edges$cause_x <- nodes$x[edges$cause_index] + edges$xoffset
    edges$cause_y <- nodes$y[edges$cause_index] + edges$yoffset
    edges$effect_x <- nodes$x[edges$effect_index] + edges$xoffset
    edges$effect_y <- nodes$y[edges$effect_index] + edges$yoffset
    
    edges$dx <- edges$effect_x - edges$cause_x
    edges$dy <- edges$effect_y - edges$cause_y
    
    edges$r <- sqrt(edges$dx * edges$dx + edges$dy * edges$dy)
    
    edges$x0 <- edges$cause_x + edges$dx * 0.25 / edges$r
    edges$y0 <- edges$cause_y + edges$dy * 0.25 / edges$r
    edges$x1 <- edges$effect_x - edges$dx * 0.25 / edges$r
    edges$y1 <- edges$effect_y - edges$dy * 0.25 / edges$r
    
    p <- ggplot() +
        theme_classic() + 
        geom_point(data = nodes, size = 25, shape = 1, aes(x = x, y = y)) +
        geom_text(data = nodes, aes(x = x, y = y, label = name), size=2.5) +
        geom_segment(
            data = edges,
            arrow = arrow(length = unit(0.25, "cm")),
            aes(x = x0, xend = x1, y = y0, yend = y1, colour = city)
        ) + facet_grid(. ~ embedding_method) +
        expand_limits(x = c(-1, 1), y = c(-1.15, 1.15)) +
        theme(
            axis.line=element_blank(),axis.text.x=element_blank(),
            axis.text.y=element_blank(),axis.ticks=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_blank(),
            legend.title=element_blank(),
            legend.margin=unit(0, "cm"),
            legend.position="bottom",
            panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
            panel.grid.minor=element_blank(),plot.background=element_blank(),
            panel.margin=unit(0, "cm"),
            strip.text=element_blank(),
            strip.background=element_blank(),
            plot.margin = unit(c(0,0,0,0), "cm")
        )
}

main()
