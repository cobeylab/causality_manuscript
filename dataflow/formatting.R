library(ggplot2)

heatmap_scale_fill <- function()
{
    scale_fill_gradient(
        limits=c(0.0, 1.0),
        low='#1111ff',
        high='#ff7777'
    )
}

make_qualitative <- function(vec) {
    factor(unlist(lapply(
        vec,
        function(x) {
            if(x <= 0.05) {
                return('L1')
            }
            else if(x < 0.95) {
                return('L2')
            }
            return('L3')
        }
    )), levels=c('L1', 'L2', 'L3'))
}
