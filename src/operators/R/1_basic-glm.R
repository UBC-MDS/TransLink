# Author: Brayden Tang
# Date: May 17th, 2020

"This script runs a basic zero-truncated Poisson model to serve as a baseline,
with no hierarchical modelling or Bayesian approaches of any kind. 
This script assumes that it will be run from the root of the repository.
Usage: 1_basic-glm.R <train_data_path> <aic_table_out> <model_out>

Options:
<train_dath_path>   A file path that gives the location of the training set.
<aic_table_out>     A file path specifying where to store a table of AIC scores for model selection.
<model_out>         A file path specifying where to store the final selected model.
" -> doc

# Import packages needed for this script

library(tidyverse)
library(VGAM)
library(docopt)

opt <- docopt(doc)

#' This function fits a zero-truncated Poisson GLM with some set of predictors
#' specified by the user.
#'
#' @param predictors A string specifying an R formula, where the 
#' formula references specific columns provided in data.
#' @param data The training dataset.
#'
#' @return A VGAM object of the fitted model.
#' @export
#'
#' @examples
#' fit_model(
#' predictors = "~ experience + cost_centre + offset(log(hours_worked_div_1957))",
#' data = data
#' )
#' 
fit_model <- function(predictors, data) {
  
  # Check that the model specification is correctly formatted.
  if (!str_detect(predictors, "~")) {
    stop("Invalid formula specification.")
  } else if (!str_detect(predictors, "offset\\(log\\(hours_worked_div_1957\\)\\)")) {
      warning("The provided formula does not have an offset term for log hours worked divided by 1957.
              Please ensure that this is intentional.")
  }
  
  # Check that data contains the right columns.
  
  if (any(c("experience", "cost_centre", "number_incidents", "hours_worked_div_1957") %in% colnames(data) == FALSE)) {
    stop("Specific columns are missing from the training data in the GLM model fit. Recheck column names!")
  }
  
  model <- vglm(
    as.formula(paste0("number_incidents", predictors)), 
    family = pospoisson(),
    data = data
  )
  
  model
  
}

#' This function selects the best predictive GLM model by selecting the best feature
#' combination amongst all possible combinations.
#'
#' @param train_path_data A file path to the training data set. Should be a specific .csv file.
#' @param aic_table_out A file path that describes where the AIC results table 
#' should be stored.
#' @param model_out A file path that describes where the best predictive GLM model 
#' should be stored.
#' @return None
#' @export
#'
#' @examples
#' main(
#' train_path_data = "data/operators/train.csv",
#' aic_table_out = "results/operators/report-tables,
#' model_out = "results/operators/models"
#' )
main <- function(train_data_path, aic_table_out, model_out) {

  # Check that the paths specified are correct.
  if (!str_detect(train_data_path, ".csv")) {
    stop("Train path must be a specific .csv file.")
  } else if (str_detect(aic_table_out, "\\.txt$|\\.csv$|\\.xlsx$|//.rds$")) {
    stop("Path to store output table of AIC scores should just be a general path. Remove file extension.")
  } else if (str_detect(model_out, "\\.txt$|\\.csv$|\\.xlsx$|//.rds$")) {
    stop("Path to store the model object should just be a general path. Remove file extension.")
  } else if (endsWith(aic_table_out, "/")) {
		stop("File path for aic_table_out should not end with /")
	} else if (endsWith(model_out, "/")) {
		stop("File path for model_out should not end with /")
	}
  
  # Read in data, preprocess
  # If cost centre is NA, just fill with the most common value which is VTC.
  # 1957 is needed to recreate the incidents/year column.
  data <- read_csv(train_data_path) %>%
    mutate(cost_centre = ifelse(is.na(cost_centre), "VTC", cost_centre)) %>%
    mutate(
      experience = factor(experience), 
      cost_centre = factor(cost_centre),
      hours_worked_div_1957 = total_hours_last3yr / 1957) %>%
    mutate(
      cost_centre = relevel(cost_centre, ref = "VTC"),
      experience = relevel(experience, ref = ">60 Months")) 
  
  # Define the combinations of predictors. Interactions don't work, model
  # oversaturates.
  predictor_combinations <- c(
    "~ experience + offset(log(hours_worked_div_1957))",
    "~ cost_centre + offset(log(hours_worked_div_1957))",
    "~ experience + cost_centre + offset(log(hours_worked_div_1957))"
  )
  
  # Fit all possible models as described above. This is 
  # exactly the same thing as a for loop, iterating over each possible
  # predictor_combination.
  all_models <- map(predictor_combinations, fit_model, data = data)
  
  # Store AIC scores in a table. Clearly, a model that has 
  # both predictors is almost certaintly a better predictive model than either
  # one alone.
  results_basic_glm <- tibble(
    "Set of Predictors" = c("Experience Only", "Cost Centre Only", "Experience and Cost Centre"),
    AIC = round(map_dbl(all_models, AIC), 2)
    )
  
  if (!dir.exists(aic_table_out)) {
  	dir.create(aic_table_out)
  }
  
  # Save AIC table in results
  saveRDS(
    results_basic_glm,
    paste0(aic_table_out, "/basic-glm-aic_table.rds")
    )
  
  # Fit final best model, and save 
  best_basic_glm <- fit_model(
    predictor_combinations[which.min(results_basic_glm$AIC)],
    data = data
    )
  
  if (!dir.exists(model_out)) {
  	dir.create(model_out)
  }
  
  saveRDS(best_basic_glm, paste0(model_out, "/basic-glm.rds"))

}

main(
  train_data_path = opt$train_data_path, 
  aic_table_out = opt$aic_table_out,
  model_out = opt$model_out
)