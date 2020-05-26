# Author: Brayden Tang
# Date: May 20th, 2020

"This script runs a variety of hierarchical Bayesian regression models, and then
selects the best one based on PSIS-LOO. Note that two model .rds objects are
created; one that contains only the best model, and another much larger file that
contains all of the other models (in case they wish to be used).
This script assumes that it will be run from the root of the repository.
Warning: this script takes a long time (over two hours) to run due to MCMC sampling! 

Usage: 2_bayesian-models.R <train_data_path> <table_out> <all_model_out> <best_model_out>

Options:
<train_data_path>   A file path that gives the location of the training set.
<table_out>         A file path specifying where to store the table of validation results for each candidate model.
<all_model_out>     A file path specifying where to store all of the models.
<best_model_out>    A file path specifying where to store the best Bayesian model.
" -> doc

library(tidyverse)
library(recipes)
library(brms)
library(parallel)
library(docopt)

opt <- docopt(doc)

# Import the needed functions stored in a separate file.        
source("src/operators/R/bayesian-fit.R")

#' Fits all of the candidate Bayesian models, and outputs relevant results
#' and fitted model objects to specified paths.
#'
#' @param train_path_data A file path that specifies where the training data is 
#' located. 
#' @param table_out A file path that specifies where to output validation results. 
#' @param all_model_out A file path that specifies where to output all of the fitted models.
#' @param best_model_out A file path that specifies where to output the best fitted model. 
#'
#' @return None
#' @export
#'
#' @examples 
#' main(
#' train_path_data = "data/operators/train.csv",
#' table_out = "results/operators/report-tables/loo-model-cv-summary-bayes.rds",
#' all_model_out = "results/operators/models/all-bayes-models.rds",
#' best_model_out = "results/operators/models/best-bayes-model.rds"
#' )
main <- function(train_data_path, table_out, all_model_out, best_model_out) {        
  
  # Check that the paths specified are correct.
  if (!str_detect(train_data_path, ".csv")) {
    stop("Train path must be a specific .csv file.")
  } else if (!str_detect(table_out, ".rds")) {
    stop("Path to store output table of LOO scores must be a specific .rds file.")
  } else if (!str_detect(all_model_out, ".rds")) {
    stop("Path to store the model object must be a specific .rds file.")
  } else if (!str_detect(best_model_out, ".rds")) {
    stop("Path to store best Bayes model must be a specific .rds file.")
  }
  
  # Read in data, preprocess
  # If cost centre is NA, just fill with the most common value which is VTC.
  data <- read_csv(train_data_path) %>%
    mutate(cost_centre = ifelse(is.na(cost_centre), "VTC", cost_centre)) %>%
    mutate(
      experience = factor(experience),
      cost_centre = factor(cost_centre),
      hours_worked_div_1957 = total_hours_last3yr / 1957) %>%
    mutate(
      cost_centre = relevel(cost_centre, ref = "VTC"),
      experience = relevel(experience, ref = ">60 Months")) 
  
  tau_val <- c(1e-2, 1e-1, 1, 5, 10)
  
  results_NH <- lapply(tau_val, fit_non_hier, data) 
  names(results_NH) <- paste0(tau_val, "nh")
  
  # Again, noticed that lower regularization works better here based on PSIS-LOO.
  tau_rand_int_only <- c(1, 5, 10, 15, 20)
  print("Done running non-hierarchical model. Now running random intercept model.")
  results_rand_int <- lapply(tau_rand_int_only, fit_rand_int, data)
  names(results_rand_int) <- paste0(tau_rand_int_only, "rand_int")
  
  # After noticing that this model below prefers lower regularization (based on PSIS-LOO),
  # change to a smaller set of values in the range of 10-20.
  tau_rand_int_slope <- seq(10, 19, 3)
  print("Done running random intercept model. Now running random slopes and random intercept model.")
  results_rand_int_slope <- lapply(tau_rand_int_slope, fit_rand_int_slope, data)
  names(results_rand_int_slope) <- paste0(tau_rand_int_slope, "rand_int_slope")
  
  results_combined <- c(results_NH, results_rand_int, results_rand_int_slope)
  saveRDS(results_combined, all_model_out)
  
  print("Done running MCMC sampling. Now calculating PSIS-LOO scores.")
  
  results_loo <- lapply(results_combined, LOO, cores = detectCores() - 2)
  loo_values <- loo_compare(results_loo)
  
  saveRDS(loo_values, table_out)
  
  final_bayes_model <- results_combined[[rownames(loo_values)[1]]]
  
  saveRDS(final_bayes_model, best_model_out)

}

main(
  train_data_path = opt$train_data_path,
  table_out = opt$table_out,
  all_model_out = opt$all_model_out,
  best_model_out = opt$best_model_out
  )