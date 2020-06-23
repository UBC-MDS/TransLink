# Author: Brayden Tang
# Date: May 24th, 2020

"This script fits the final chosen model on the entire dataset for the 
interactive report. This script assumes it will be run from the root of 
the repository.

Usage: 4_final-model.R <path_train> <path_test> <chosen_model> <final_model_out> <posterior_samples_out>

Options:
<path_train>      A file path that specifies the training set.
<path_test>       A file path that specifies the test set.
<chosen_model>    A file path that specifies the chosen model in validation.
<final_model_out> A file path that specifies where to output the final fitted model.
<posterior_samples_out> A file path that specifies where to output the posterior predictive samples for each combination of cost centre and experience.
" -> doc

library(tidyverse)
library(parallel)
library(brms)
library(docopt)

# Source the required functions to fit the best Bayesian model
source("src/operators/R/helper_scripts/bayesian-fit.R")
opt <- docopt(doc)
#' This function fits the final model on the entire dataset and outputs
#' relevant plots and tables for the interactive report.
#'
#' @param path_train A file path that specifies the training set.
#' @param path_test A file path that specifies the test set.
#' @param chosen_model A file path that specifies the chosen model in validation.
#' @param final_model_out A file path that specifies where to output the final fitted model.
#' @param posterior_samples_out A file path that specifies where to output the
#' posterior predictive samples for each combination of cost centre and experience.
#'
#' @return None
#' @export
#'
#' @examples
#' main(
#' path_train = "data/operators/train.csv",
#' path_test = "data/operators/test.csv",
#' chosen_model = "results/operators/models/best-bayes-model.rds",
#' final_model_out = "results/operators/models",
#' posterior_samples_out = "results/operators/report-tables"
#' )
main <- function(path_train, path_test, chosen_model, final_model_out, posterior_samples_out) {
  
  # Input validation checks. Checks for correctly specified file paths.
  if (!str_detect(path_train, ".csv")) {
    stop("File path to train must be a specific file with extension .csv")
  } else if (!str_detect(path_test, ".csv")) {
    stop("File path to test must be a specific file with extension .csv")
  } else if (!str_detect(chosen_model, ".rds")) {
    stop("File path to chosen model in validation must be a specific file with extension .rds")
  } else if (str_detect(final_model_out, "\\.txt$|\\.csv$|\\.xlsx$|//.rds$")) {
  	stop("final_model_out should just be a directory, not a specific file. Remove the file extension.")
  } else if (str_detect(posterior_samples_out, "\\.txt$|\\.csv$|\\.xlsx$|//.rds$")) {
  	stop("posterior_samples_out should just be a directory, not a specific file. Remove the file extension.")
  } else if (endsWith(final_model_out, "/")) {
  	stop("File path for final_model_out should not end with /")
  } else if (endsWith(posterior_samples_out, "/")) {
  	stop("File path for posterior_samples_out should not end with /")
  } 
  # Read in both train and test
  train <- read_csv(path_train)
  test <- read_csv(path_test)
  
  # Combine both train and test, and then carry out preprocessing as we did
  # in validation.
  combined <- bind_rows(train, test) %>%
    mutate(cost_centre = ifelse(is.na(cost_centre), "VTC", cost_centre)) %>%
    mutate(
      experience = factor(experience),
      cost_centre = factor(cost_centre),
      hours_worked_div_1957 = total_hours_last3yr / 1957) %>%
    mutate(
      cost_centre = relevel(cost_centre, ref = "VTC"),
      experience = relevel(experience, ref = ">60 Months")) 
  
  rm(train, test)
  
  # Load chosen_model
  best_model <- readRDS(chosen_model)
  
  # Get the tau value used from the best model
  tau <- best_model$stanvars$tau$sdata
  rm(best_model)
  
  # Fit the model and save 
  final_model <- fit_rand_int_slope(tau = tau, data = combined)
  
  if (!dir.exists(final_model_out)) {
  	dir.create(final_model_out)
  }
  
  saveRDS(final_model, paste0(final_model_out, "/final-model.rds"))
  
  # Generate all combinations of predictors for report. This will give
  # us predicted rates, i.e. Incidents/Year since we have offset = 0.
  all_combinations <- tibble(
    expand.grid(
      experience = unique(final_model$data$experience),
      cost_centre = unique(final_model$data$cost_centre),
      hours_worked_div_1957 = 1
    )
  ) 
  
  # Get posterior samples
  set.seed(200350623)
  predictions <- posterior_predict(
    final_model,
    newdata = all_combinations,
    summary = FALSE
    )
  
  if (!dir.exists(posterior_samples_out)) {
  	dir.create(posterior_samples_out)
  }
  
  # Save posterior predictive samples
  saveRDS(
    list(
      variables = all_combinations,
      posterior_samples = predictions
      ),
    paste0(posterior_samples_out, "/posterior_samples.rds")
    )
}

main(
  path_train = opt$path_train,
  path_test = opt$path_test,
  chosen_model = opt$chosen_model, 
  final_model_out = opt$final_model_out,
  posterior_samples_out = opt$posterior_samples_out 
)