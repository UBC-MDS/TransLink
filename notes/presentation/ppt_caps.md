---
title       : Vision over Transit Incidents and Claims
subtitle    : Data Driven Approaches to Reducing Insurance Costs to TransLink
author      : Merve Sahin, Brayden Tang, Simardeep Kaur, Xugang Zhong
job         : UBC MDS Capstone
framework   : io2012        # {io2012, html5slides, shower, dzslides, ...}
highlighter : prettify      # {highlight.js, prettify, highlight}
hitheme     : tomorrow      # 
widgets     : [bootstrap]   # {mathjax, quiz, bootstrap}
mode        : selfcontained # {standalone, draft}
knit        : slidify::knit2slides
---



## Overview

- Business Questions
- Research Questions of Interest to address 1.
- Data Overview
- Data Product
- Proposed Methodology
- Rough Timeline

--- {.build}
## Business Question - high costs

> * Insurance premium is one of the largest spendings in TransLink's budget
> * In the past five years, claim costs have increased by about **122.5%**
> * Therefore, we have been asked to find:
  - .fragment potential strong predictors of claim severity/frequency that TransLink can leverage to help reduce costs
  
*** pnotes
- On average, premiums have increased by approximately $2 million, or 17.5%, per year during this period. 
- On average, TransLink has over 1,100 ICBC claims per year costing approximately $13 million per year.
- There are approximately 240 collision claims per year that on average cost $3.5K per claim
- The results of this data analysis would be used to develop loss mitigation plans that will avoid or reduce TransLink claims costs.

---
## Research Questions

- What are the main predictors of the frequency and severity of bus accidents?
       - Driver characteristics (probation period, experience)
       - Claim types and other accident descriptions
       - Bus model/model year
       - Bus routes
       - Acceleration/decceleration
       - Weather
       - Time
       - Geographic location
       - and more
    
*** pnotes
- The ... refer to other potential predictors of accident experience
- Categorical features include claim type codes (ATPA codes which are well defined categorical codes, and ATPA code descriptions that are written manually by a human) 

---

## Research Questions (cont)

- Within specific categorical features (such as claim type codes), are there specific clusters or groupings that are particularly noteworthy for having worse or better claims/accident experience?

---
## High Level Data Descriptions

- Bus Speeds for All Routes, Route Information
- Actual Incidient Reports
- Collisions (Preventable and Non-Preventable)
- Claims

*** pnotes

- First one is , Speed Performance which as the name suggests gives information
about scheduled speeds and actual speeds with which the vehicle traveled along with the
scheduled and actual timings of the bus.
- Second dataset tells us about how different drivers are related with the different number
of incidents. This dataset gives a clear idea about the relationship of the drivers and their
characteristics with incidents.
- Third data set provides a detailed description of the collisions that took place, both
preventable and not preventable.
- Then at last, Translink will provide us the data about different claims that has been. We
so not have this data yet, this will be available in future.

--- {.build}

## Bus Speeds for All Routes, Route Information

> <img src="images/speed_data.png" alt="drawing" style="width:500px;" class = "center"/>

---

## Actual Incidient Reports

> <img src="images/operator_incident.png" alt="drawing" style="width:500px;" class = "center"/>

---

## Collisions (Preventable and Non-Preventable)

> <img src="images/collision_data.png" alt="drawing" style="width:500px;" class = "center"/>

---

## Claims

> <img src="images/claim_data.png" alt="drawing" style="width:500px;" class = "center"/>

---

## Data Product

> * A reproducible, **interactive** report that allows the reader to:
    - .fragment visualize relationships between claim frequency/severity and specific variables interactively
    - .fragment query a predictive model, again interactively and perhaps through an interactive map

> * <img src="sketch.png" alt="drawing" style="width:500px;" class = "center"/>

---

## Data Product (cont)

> * A fully reproducible data pipeline
    - .fragment user-friendly way to run the entire data analysis front to back using simple Make commands
    - .fragment stored on a Docker container
    - .fragment detailed documentation describing how to run the analysis and the code

---

## Methodology

- Join the Collision and Incident Operators datasets with respect to some id (if given) and then split the whole dataset into test and train datasets
- Exploratory Data Analysis on the resulting training set (visualizations to assess potential predictors of interest such as density plots, boxplots, barcharts, etc.)

*** pnotes

- We (hopefully) expect in the coming days the ability to JOIN the datasets together (operator incidents with claims and bus speeds) so that we can properly answer the specific predictive questions asked. This is pretty crucial.
- If we lose the ability to join, we will likely be limited in relationships we can explore since we will have no ability to relate accidents with multiple factors of interest (like speed, location, route, etc.)

---

## Methodology (cont)

- If complete data is provided, a regression model on incident rate/year based off driver characteristics, time of day, etc.
- A Bayesian regression model to address the problem of truncation in the Incident Operators dataset or a Zero-Truncated Model (if complete data is not provided)
- Cluster Analysis for analysis of specific categorical features like claim type code, claim description (Markov Chains, LDA, DBSCAN)

*** pnotes

- Complete data: as in, no truncation. In other words, we have all of the drivers, **including those who have 0 accidents.**
- If we are forced to work only with those who are observed to have an incident, we can consider truncated counting models (Pr[X = x | X > 0]) either in frequentist or a Bayesian framework, since we are only sampling part of the observed distribution. This assumes a world with no possibility of 0 accidents, that is, in order for an operator to appear as an observation, they must have first gotten into an accident.
- This has the advantage that we do not explicitly model Pr[X = 0] using data in which this case does not exist, simply throw it away. We don't really care about modelling Pr[X = 0] anyway.
- The Bayesian method can also be used to assign some subjective probability of Pr[X = 0] in light of no data.
- All of this is moot if we can obtain data for all operators, regardless if they have had accidents or not.
- the cluster analysis is related to the specific question of whether we can find particular coverage codes and/or specific words in accident descriptions that are correlated with particularly bad accident experience

--- 

## Rough Timeline (May 4 - May 25)

- Milestone 0 (May 11, 2020):
 - finalize proposal report
 
<br />
- Milestone I (May 25, 2020):
  - finalize dataset preprocessing.
  - create the data pipeline.
  - complete all of the analysis described in the methodology
     - build predictive model
     - answer the specific hypotheses proposed by TransLink

--- 

## Rough Timeline (May 25 - June 23)

- Milestone II (June 15, 2020):
  - first draft of the final report
  - create Docker container for the data pipeline
  
- Milestone III (June 18, 2020):
  - complete the final presentation to TransLink

- Milestone IV (June 23, 2020):
  - complete interactive report based on feedback
  - finish the data pipeline
  
***pnotes 
-(M2)add interaction on the plots.
