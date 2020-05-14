# Import packages needed to run this analysis

library(readxl)
library(tidyverse)
library(janitor)
library(caret)
library(docopt)

# Read in the data

data <- read_xlsx("data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx", sheet = 2) %>%
  janitor::clean_names() %>%
  mutate(incidents_1957 = number_incidents * 1957)

# Split into train and test

set.seed(200350623)

train_folds <- createDataPartition(y = data$incidents_1957, p = 0.85)
train <- data[train_folds[[1]], ]
test <- data[-train_folds[[1]], ]

write_csv(train, "data/operator_train_test/train.csv")
write_csv(test, "data/operator_train_test/test.csv")