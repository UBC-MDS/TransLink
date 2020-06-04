library(dplyr)
library(tidyverse)
library(readxl)
collision_table <- read_excel("../data/TransLink Raw Data/Updated_tags_df.xlsx")
collision_table$month <- format(as.Date(collision_table$`Date of Incident`), "%m")
input_string = 'mirror'
collision_table <- collision_table %>% mutate(impact_test = ifelse(impact == input_string, input_string, paste('not_',input_string)))
chi_test_data <- table(collision_table$impact_test, collision_table$month)
chisq.test(chi_test_data)
