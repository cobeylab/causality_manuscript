library(rjson)

load_job_info <- function(db)
{
    dbGetQuery(db, 'SELECT * FROM job_info ORDER BY job_id')
}

get_job_ids <- function(db)
{
    dbGetQuery(db, 'SELECT job_id FROM job_info ORDER BY job_id')$job_id
}

load_timeseries <- function(db, job_id)
{
    dbGetPreparedQuery(
        db, 
        'SELECT logI0, logI1, C0, C1 FROM timeseries WHERE job_id = ? ORDER BY ind',
        data.frame(job_id = job_id)
    )
}

get_C_1000y_monthly <- function(timeseries)
{
    return(timeseries[,c('C0', 'C1')])
}

get_C_100y_monthly <- function(timeseries)
{
    N <- nrow(timeseries)
    return(timeseries[(N - 100 * 12 + 1):N, c('C0', 'C1')])
}


get_C_1000y_annual <- function(timeseries)
{
    monthly <- get_C_1000y_monthly(timeseries)
    annual <- matrix(nrow=1000, ncol=2)
    for(i in 1:1000) {
        start <- 12 * (i-1) + 1
        annual[i,] <- apply(monthly[start:(start+11),], 2, sum)
    }
    return(annual)
}

get_C_1000y_annual_fd <- function(timeseries)
{
    nofd <- get_C_1000y_annual(timeseries)
    nofd[2:nrow(nofd),] - nofd[1:(nrow(nofd)-1),]
}

get_C_1000y_annual_log_fd <- function(timeseries)
{
    nofd <- log(get_C_1000y_annual(timeseries))
    nofd[2:nrow(nofd),] - nofd[1:(nrow(nofd)-1),]
}

get_C_1000y_biennial <- function(timeseries)
{
    monthly <- get_C_1000y_monthly(timeseries)
    biennial <- matrix(nrow=500, ncol=2)
    for(i in 1:500) {
        start <- 24 * (i-1) + 1
        biennial[i,] <- apply(monthly[start:(start+23),], 2, sum)
    }
    return(biennial)
}

get_I_1000y_monthly <- function(timeseries)
{
    return(exp(timeseries[,c('logI0', 'logI1')]))
}

get_I_1000y_annual <- function(timeseries)
{
    monthly <- get_I_1000y_monthly(timeseries)
    annual <- matrix(nrow=1000, ncol=2)
    for(i in 1:1000) {
        annual[i,] <- monthly[12 * (i-1) + 4,] # offset by 3 months to yield point of max beta
    }
    return(annual)
}
