library(rjson)

dump_lines <- function(lines, filename)
{
    conn <- file(filename, 'w')
    cat(lines, sep='\n', file=conn)
    cat('\n', file=conn)
    close(conn)
}

dump_json <- function(obj, filename)
{
    conn <- file(filename, 'w')
    cat(toJSON(obj), file=conn)
    cat('\n', file=conn)
    close(conn)
}

load_json <- function(filename)
{
    conn <- file(filename, 'r')
    lines <- readLines(conn)
    close(conn)
    
    return(fromJSON(paste(lines, sep='\n')))
}

load_json_matrix <- function(filename)
{
    json_struct <- load_json(filename)
    matrix(unlist(json_struct), nrow=length(json_struct), byrow=T)
}
