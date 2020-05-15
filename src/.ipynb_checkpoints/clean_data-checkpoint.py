#!/usr/bin/env python
# coding: utf-8


import pandas as pd

Speed_performance = pd.read_csv('data/TransLink Raw Data/Speed performance data.csv', low_memory=False)

Collision_preventable = pd.read_excel('data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx', skiprows=  3)

Collision_non_preventable = pd.read_excel('data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx', skiprows=  3, sheet_name=1)

Incident_operator = pd.read_excel('data/TransLink Raw Data/Operator With Incident Last 3 Years.xlsx', sheet_name=1)




