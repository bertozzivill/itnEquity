###############################################################################################################
## itn_equity_functions.r
## Amelia Bertozzi-Villa
## December 2023
## 
## Collect functions for the ITN equity project
##############################################################################################################


# it seems like Hmisc::wtd.quantile() has major bugs https://github.com/harrelfe/Hmisc/issues/97... 
# try this solution from that github issue
wtd.quantile<- function (x, weights = NULL, probs = c(0, 0.25, 0.5, 0.75, 1),
                         type = c("quantile", "(i-1)/(n-1)", "i/(n+1)", "i/n"),
                         na.rm = TRUE)  {
  # Function taken from HMISC, but issue solved which is documented here: https://github.com/harrelfe/Hmisc/issues/97#issuecomment-429634634
  normwt = FALSE
  if (!length(weights))      return(quantile(x, probs = probs, na.rm = na.rm))
  type <- match.arg(type)
  if (any(probs < 0 | probs > 1))      stop("Probabilities must be between 0 and 1 inclusive")
  nams <- paste(format(round(probs * 100, if (length(probs) >
                                              1) 2 - log10(diff(range(probs))) else 2)), "%", sep = "")
  
  if(na.rm & any(is.na(weights))){   ###### new
    i<- is.na(weights)
    x <- x[!i]
    weights <- weights[!i]
  }
  i <- weights <= 0         # nwe: kill negative and zero weights and associated data
  if (any(i)) {
    x <- x[!i]
    weights <- weights[!i]
  }
  if (type == "quantile") {
    if(sum(weights) < 1000000 ) {weights<- weights*1000000/sum(weights)}  ##### new
    w <- wtd.table(x, weights, na.rm = na.rm, normwt = normwt,
                   type = "list")
    x <- w$x
    wts <- w$sum.of.weights
    n <- sum(wts)
    order <- 1 + (n - 1) * probs
    low <- pmax(floor(order), 1)
    high <- pmin(low + 1, n)
    order <- order%%1
    allq <- approx(cumsum(wts), x, xout = c(low, high), method = "constant",
                   f = 1, rule = 2)$y
    k <- length(probs)
    quantiles <- (1 - order) * allq[1:k] + order * allq[-(1:k)]
    names(quantiles) <- nams
    return(quantiles)
  }
  w <- wtd.Ecdf(x, weights, na.rm = na.rm, type = type, normwt = normwt)
  structure(approx(w$ecdf, w$x, xout = probs, rule = 2)$y,
            names = nams)
}


# Functions to aggregate and summarize surveys

find_svymean <- function(svy_metric, svy_design){
  mean_dt <- svymean(make.formula(svy_metric), 
                     svy_design, na.rm=T)
  mean_dt <- as.data.table(mean_dt, keep.rownames=T)
  mean_dt[, weighting_type:=svy_design$weights_name]
  mean_dt[, metric:=svy_metric]
  return(mean_dt)
}

find_svyby <- function(svy_by, svy_metric, svy_design){
  mean_dt <- svyby(make.formula(svy_metric),
                   by = make.formula(svy_by),
                   design = svy_design, svymean,
                   na.rm=T)
  mean_dt <- as.data.table(mean_dt)
  mean_dt[, weighting_type:=svy_design$weights_name]
  
  mean_dt[, metric:=svy_by]
  return(mean_dt)
}

set_up_survey <- function(weights, data, ids){
  this_survey_design <- svydesign(data=data,
                                  ids= as.formula(paste("~", ids)), 
                                  weights= as.formula(paste("~", weights)))
  this_survey_design$weights_name <- weights
  return(this_survey_design)
}

summarize_survey <- function(weight_vals, data, ids, metric_vals, by_vals=NULL){
  svy_designs <- lapply(weight_vals, set_up_survey, data=data, ids=ids)
  
  if (length(by_vals)==0){
    all_means <- rbindlist(lapply(svy_designs, 
                                  function(this_survey_design){
                                    rbindlist(lapply(metric_vals,
                                                     find_svymean,
                                                     svy_design=this_survey_design))
                                  }))
  }else{
    all_means <- rbindlist(lapply(svy_designs, 
                                  function(this_survey_design){
                                    rbindlist(lapply(by_vals,
                                                     find_svyby,
                                                     svy_metric=metric_vals,
                                                     svy_design=this_survey_design),
                                              use.names=F)
                                  }))
  }
  
  return(all_means)
}

