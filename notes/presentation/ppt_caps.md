---
title       : Vision over Transit Incidents and Claims
subtitle    : Data Driven Approaches to Reducing Insurance Costs to TransLink
author      : Merve Sahin, Brayden Tang, Simardeep Kaur, Xugang Zhong
job         : UBC MDS Capstone
framework   : io2012        # {io2012, html5slides, shower, dzslides, ...}
highlighter : prettify      # {highlight.js, prettify, highlight}
hitheme     : tomorrow      # 
widgets     : []            # {mathjax, quiz, bootstrap}
mode        : selfcontained # {standalone, draft}
knit        : slidify::knit2slides
---



--- {.build}
## Business Question - high costs

> * Insurance premium is one of the largest spendings in TransLink's budget
> * Therefore, we have been asked to find:
  - .fragment the patterns between different conditions of claims
  - .fragment potential strong predictors of interest that TransLink can leverage to help reduce claim severity/frequency

---
## Research Questions

- What are the main predictors of the frequency and severity of bus accidents?
       - Driver characteristics
       - APTA description and other accident descriptions
       - Bus model/model year
       - Acceleration/Decceleration
       - Weather
       - Time
       - Geographic location
       - ...
    
- Within specific categorical features, are there specific clusters or groupings that are particularly noteworthy for having worse or better claims experience?  

---
## High Level Data Descriptions

- Speed Performance
- Incident Operators
- Collisions (Preventable and Non-Preventable)
- Claims

--- {.build}
## Data Product

> * A reproducible, **interactive** report that allows the reader to:
    - .fragment visualize relationships between claim frequency/severity and specific variables interactively
    - .fragment potentially query a predictive model, again interactively
  
<sketch of report here?>
-- 

---
## Methodology

- Supervised Learning Techniques (with an emphasis on prediction)
- Cluster Analysis for analysis of specific categorical features (k-means, DBSCAN, or any other method that gives well defined labels)
- Exploratory Data Analysis (visualizations such as bar charts, histograms, density plots, etc.)
- Possibly a rigorous statistical analysis to infer significant correlations if the EDA looks promising

## Rough Timeline

- 
## 



