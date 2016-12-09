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
library(gridExtra)
library(ggplot2)

### EXTERNAL SOURCE ###

source('../../formatting.R')
source('../../file_output.R')
source('./')

main <- function()
{
    db_filename <- '../../in/ccm-analyses/100y-monthly-incidence-untransformed/surrogates/results_gathered.sqlite'
    df <- load_summary(db_filename)
    print(df)
    
    df$cause <- factor(df$cause, levels=c('C1', 'C0'))
    
    df$frac_greater_str <- sapply(
        df$frac_greater,
        function(x) {
            sprintf('%.2f', x)
        }
    )
    
    generate_plot(df, 0)
    generate_plot(df, 1)
    html2pdf('fig_surrogates', html2pdf_path = '../../html2pdf/html2pdf.app/Contents/MacOS/html2pdf')
}

generate_plot <- function(df, use_effect_surrogates)
{
    df <- df[df$use_effect_surrogates == use_effect_surrogates,]
    
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
        data = df,
        aes(x = factor(sd_proc), y = factor(sigma01))
    ) +
        geom_tile(aes(fill = frac_greater)) +
        geom_text(colour = 'lightgray', size = 3, aes(label = frac_greater_str)) +
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
        theme(
            plot.margin = unit(c(0,0,0,1), 'cm')
        ) +
        heatmap_scale_fill() +
        scale_colour_manual('', values=c('black', NA, 'black'), guide=FALSE)
    
    filename_prefix <- sprintf('fig_surrogates_useeffect=%d', use_effect_surrogates)
    ggsave_pdf2svg(filename_prefix, p, width=6, height=2, inkscape_path = '/Applications/Inkscape.app/Contents/Resources/bin/inkscape')
}

load_data <- function(db_filename)
{
    db <- dbConnect(SQLite(), db_filename)
    
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS job_info_index ON job_info (job_id, eps, beta00, sigma01, sd_proc)')
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS surrogate_test_index ON surrogate_test (job_id, cause, effect, use_effect_surrogates)')
    
    df <- dbGetQuery(db, '
        SELECT job_info.job_id AS job_id, eps, beta00, sigma01, sd_proc, replicate_id,
             cause, effect, use_effect_surrogates,
             corr_raw, corr_surr_q95, pvalue_greater
         FROM job_info, surrogate_test
         WHERE job_info.job_id = surrogate_test.job_id;
    ')
    
    dbDisconnect(db)
    
    return(df)
}

load_summary <- function(db_filename)
{
    db <- dbConnect(SQLite(), db_filename)
    
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS job_info_index ON job_info (job_id, eps, beta00, sigma01, sd_proc)')
    dbGetQuery(db, 'CREATE INDEX IF NOT EXISTS surrogate_test_index ON surrogate_test (job_id, cause, effect, use_effect_surrogates)')
    
    df <- dbGetQuery(db, '
        SELECT sigma01, sd_proc,
            cause, effect, use_effect_surrogates,
            COUNT(*) as n_replicates,
            AVG(corr_raw) AS corr_raw_mean,
            AVG(corr_surr_q95) AS corr_surr_q95_mean,
            AVG(pvalue_greater) AS pvalue_greater_mean,
            AVG((corr_raw > corr_surr_q95) * 1.0) AS frac_greater
        FROM job_info, surrogate_test
        WHERE job_info.job_id = surrogate_test.job_id
        AND beta00 = 0.30 AND eps = 0.10
        GROUP BY sigma01, sd_proc, cause, effect, use_effect_surrogates
    ')
    
    dbDisconnect(db)
    
    return(df)
}

main()
