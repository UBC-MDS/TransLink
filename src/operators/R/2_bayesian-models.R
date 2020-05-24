# Author: Brayden Tang
# Date: May 20th, 2020

"This script runs a variety of hierarchical Bayesian regression models, and then
selects the best one based on PSIS-LOO. Note that two model .rds objects are
created; one that contains only the best model, and another much larger file that
contains all of the other models (in case they wish to be used).
This script assumes that it will be run from the root of the repository.
Warning: this script takes a long time (over two hours) to run due to MCMC sampling! 

Usage: bayesian-models.R <train_data_path> <table_out> <all_model_out> <best_model_out>

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
        

# Non-Hierarchical Bayesian Model
        
#' This function fits a non-hierarchical fully Bayesian regression model.
#' This is the Bayesian equivalent of the basic GLM that we fit previously.
#'
#' @param tau A positive number indicating how much shrinkage towards zero should be
#' applied on the coefficients. A larger value indicates less shrinkage.
#' @param data The training data.
#'
#' @return A brmsfit model that contains all of the posterior samples for all of
#' the parameters described in the model.
#' @export
#'
#' @examples 
#' fit_non_hier(tau = 0.1, data = train)
fit_non_hier <- function(tau, data) {
        
  stanvars <- stanvar(tau, name = "tau")    
  prior_non_hier <- prior(normal(0, tau), class = "b")
        
  non_hierarchial <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + cost_centre + offset(log(hours_worked_div_1957)),
    prior = prior_non_hier,
    family = poisson(),
    chains = detectCores() - 2,
    iter = 3000,
    warmup = 500, 
    seed = 200350623, 
    cores = detectCores() - 2,
    data = data,
    thin = 5,
    stanvars = stanvars
    )
        
  non_hierarchial
        
}
        
        
# Random Intercept Model
        
#' This function fits a random effect (i.e. random intercept) Bayesian model.
#' In other words, this model allows the intercept of the regression to vary
#' between groups.
#'
#' @param tau A positive number indicating how much shrinkage towards zero should be
#' applied on the coefficients. A larger value indicates less shrinkage.
#' @param data The training data.
#'
#' @return A brmsfit model that contains all of the posterior samples for all of
#' the parameters described in the model.
#' @export
#'
#' @examples
#' fit_rand_int(tau = 8, data = train)
fit_rand_int <- function(tau, data) {
          
  stanvars <- stanvar(tau, name = "tau")    
  prior_rand_int <- prior(normal(0, tau), class = "b")
          
  rand_int <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + (1 | cost_centre) + offset(log(hours_worked_div_1957)),
    prior = prior_rand_int,
    family = poisson(),
    iter = 3000,
    warmup = 500,
    chains = detectCores() - 2,
    seed = 200350623, 
    cores = detectCores() - 2,
    thin = 5,
    data = data,
    stanvars = stanvars
    )
          
  rand_int
          
}
        
# Random Slope and Intercept Model
        
#' This function fits a random effect AND random slope model (experience) in a fully Bayesian
#' framework. In other words, it allows for the intercepts and the slopes to vary 
#' between groups.
#'
#' @param tau A positive number indicating how much shrinkage towards zero should be
#' applied on the coefficients. A larger value indicates less shrinkage.
#' @param data The training data.
#'
#' @return A brmsfit model that contains all of the posterior samples for all of
#' the parameters described in the model.
#' @export
#'
#' @examples
#' fit_rand_int_slope(tau = 13, data = train)
fit_rand_int_slope <- function(tau, data) {
          
  stanvars <- stanvar(tau, name = "tau")    
  prior_rand_slope <- prior(normal(0, tau), class = "b")
          
  rand_int_slope <- brm(
    number_incidents | trunc(lb = 1) ~ 1 + experience + (1 + experience | cost_centre) + offset(log(hours_worked_div_1957)),
    prior = prior_rand_slope,
    family = poisson(),
    iter = 3000,
    chains = detectCores() - 2,
    seed = 200350623, 
    warmup = 500,
    thin = 10,
    cores = detectCores() - 2,
    data = data,
    stanvars = stanvars
    )
          
  rand_int_slope
          
}

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