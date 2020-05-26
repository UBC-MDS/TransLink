# This script is NOT needed for the interactive report, but for 
# sample purposes only to get a gauge as to what is worth showing/exploring
# in the interactive report.

# Import packages needed to run this analysis

library(tidyverse)
library(janitor)
library(plotly)
library(shiny)
library(ggthemes)

# Read in the data

data <- read_csv("data/operators/train.csv") %>%
  janitor::clean_names() %>%
  mutate(experience = factor(experience, levels = c(
    "<6 Months", ">6 & 18 Months", ">18 & <60 Months", ">60 Months"
    )))

# Perform EDA

# Boxplot
# In the interactive report:
# This graph will allow for selection of different experience levels
# Allows one to select incidents/yr, preventables/yr and non/preventables
boxplot_experience <- ggplot(data, aes(x = experience, y = incidents_year)) +
  geom_boxplot() +
  theme_economist() +
  coord_flip() +
  labs(
    title = "Incidents/Year with Experience",
    x = "\nExperience",
    y = "\nIncidents/Year"
    )

boxplot_experience +
  theme(text = element_text(size = 16),
        axis.text = element_text(size=12),
        axis.title.y = element_text(vjust = 6))

ggplotly(boxplot_experience)


