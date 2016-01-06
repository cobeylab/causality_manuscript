library(ggplot2)

heatmap_scale_fill <- function(lo=0.0, hi=1.0)
{
    scale_fill_gradient(
        limits=c(lo, hi),
        low='#1111ff',
        high='#ff7777'
    )
}

extract_legend <- function(p)
{
    g <- ggplotGrob(p)$grobs
    g_legend <- g[[which(sapply(g, function(x) x$name) == "guide-box")]]
    print(length(g_legend))
    print(g_legend)
    g_legend
}

