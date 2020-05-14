# Import packages needed to run this analysis

library(readxl)
library(tidyverse)

# Read in the data

data <- read_xlsx("data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx", sheet = 2)

# Perform EDA

