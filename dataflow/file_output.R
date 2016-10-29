ggsave_pdf2svg <- function(filename_prefix, p, width=7, height=7)
{
    filename <- sprintf('%s.pdf', filename_prefix)
    ggsave(filename, p, width=width, height=height)
    pdf2svg(filename_prefix)
    file.remove(filename)
}

pdf2svg <- function(filename_prefix)
{
    abspath <- function(filename) {
        sprintf('`python -c \'import os; print(os.path.abspath("%s"))\'`', filename)
    }
    
    src_filename <- sprintf('%s.pdf', filename_prefix)
    dst_filename <- sprintf('%s.svg', filename_prefix)
    
    system(
        sprintf('inkscape "%s" --export-plain-svg="%s"', abspath(src_filename), abspath(dst_filename))
    )
}

html2pdf <- function(filename_prefix)
{
    src_filename <- sprintf('%s.html', filename_prefix)
    dst_filename <- sprintf('%s.pdf', filename_prefix)
    
    system(sprintf('html2pdf "%s" "%s"', src_filename, dst_filename))
}

html2eps <- function(filename_prefix)
{
    src_filename <- sprintf('%s.html', filename_prefix)
    dst_filename <- sprintf('%s.eps', filename_prefix)
    
    system(sprintf('html2pdf "%s" "%s"', src_filename, dst_filename))
}

pdf2eps <- function(filename_prefix)
{
    abspath <- function(filename) {
        sprintf('`python -c \'import os; print(os.path.abspath("%s"))\'`', filename)
    }
    
    src_filename <- sprintf('%s.pdf', filename_prefix)
    dst_filename <- sprintf('%s.eps', filename_prefix)
    
    system(
        sprintf('inkscape "%s" --export-eps="%s"', abspath(src_filename), abspath(dst_filename))
    )
}
