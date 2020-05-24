# Author: Brayden Tang
# Date: May 13th, 2020

"This script reads in the raw data and then splits it into train/test sets.
The files are stored in the main data folder. This script assumes that the user
is running this script from the root of the repository.
Usage: wrangle.R <path_data> <directory_out>

Options:
<path_data>       A file path that gives the location of the raw data.
<directory_out>   A file path specifying where to store the train and test data sets.
" -> doc

# Import packages needed to run this script

library(readxl)
library(tidyverse)
library(janitor)
library(caret)
library(docopt)

# Store document string as doc object.

opt <- docopt(doc)

#' This function reads in the raw data, and splits into train and test based 
#' on a path given by the user.
#'
#' @param path_data A file path that gives the location of the raw data.
#' @param directory_out A file path specifying where to store the train and 
#' test sets.
#'
#' @return None
#' @export
#'
#' @examples 
#' main(
#' path_data = "data/TransLink Raw Data/Operator with Incident Last 3 Years.xlsx",
#' directory_out = "data/operators"
#' )
main <- function(path_data, directory_out) {

  # If the directory does not exist, create it to avoid R error.
  if (!dir.exists(directory_out)) {
    dir.create(directory_out)
  }
  
  # Check if data supplied is a .xlsx file.
  if (!str_detect(path_data, ".xlsx|.csv")) {
    stop("File path to data must be a specific .xlsx file where the second sheet contains the data, or a .csv file.")
  }

  # Read in the data differently depending on the extension.
  if (str_detect(path_data, ".xlsx")) {    
    data <- read_xlsx(path_data, sheet = 2) 
  } else {
    data <- read_csv(path_data)
  }
  
  # Check for specific columns in a specific format.  
  if (any(c("Experience", "Cost Centre", "# Incidents", "Total Hours Last3yr") %in% colnames(data) == FALSE)) {
    stop("Data is missing specific column names required for this analysis. Columns specifically entitled
         Experience, Cost Centre, # Incidents, and Total Hours Last3yr are required.")
  }
  
  # Check if output directory is specified correctly.
  if (endsWith(directory_out, "/")) {
    stop("File path should not end with /")
  }
  
  # Check if output directory is just a general path, and not a specific file.
  if (str_detect(directory_out, "\\.txt$|\\.csv$|\\.xlsx$|//.rds$")) {
    stop("Output path should just be a directory, not a specific file. Remove the file extension.")
  }
  
  data <- data %>%
    janitor::clean_names() %>%
    mutate(incidents_1957 = number_incidents * 1957)
  
  # Split into train and test
  
  set.seed(200350623)
  train_folds <- createDataPartition(y = data$incidents_1957, p = 0.85)
  train <- data[train_folds[[1]], ]
  test <- data[-train_folds[[1]], ]
  
  write_csv(train, paste0(directory_out, "/train.csv"))
  write_csv(test, paste0(directory_out, "/test.csv"))

}

main(opt$path_data, opt$directory_out)