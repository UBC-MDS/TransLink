#!/usr/bin/env python
# coding: utf-8

"""
This script fits the final model and generate results from this model for use in the report.
It takes train, test and bus information datasets and combines them to fit the final model.
It also takes the path for the final model and writes the results to the output file. 

Usage: 3_model_generator.py --train_file_path=<train_file_path> --bus_file_path=<bus_file_path> \
--test_file_path=<test_file_path> --model_file_path=<model_file_path> --path_out=<path_out>

Options:
--train_file_path=<train_file_path> A file path containing the train dataset.
--bus_file_path=<bus_file_path> A file path containing other bus information.
--test_file_path=<test_file_path> A file path containing the test dataset.
--model_file_path=<model_file_path> A file path containing the final model selected from optimization.
--path_out=<path_out> A file path that specifies where to output needed files for the interactive report.

"""

import numpy as np
import time
import pandas as pd
import datetime
import os
from pathlib import Path

# classifiers / models
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import ShuffleSplit
from sklearn.ensemble import RandomForestClassifier
from lightgbm import LGBMClassifier
from shap import TreeExplainer, summary_plot
# Preprocessors 
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from pylab import savefig
import matplotlib.pyplot as plt
# other
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split, GridSearchCV, StratifiedKFold
from docopt import docopt
import pickle


opt = docopt(__doc__)

def main(train_file_path, bus_file_path, test_file_path, model_file_path, path_out):

    # load bus information
    other_bus_info = pd.read_csv(bus_file_path)
    columns_bus_info = ["bus_no", "asset_class", "asset_manufactmodel"]
    other_bus_info = other_bus_info.loc[:, columns_bus_info]

    # load train data and test data
    train = pd.read_csv(train_file_path)
    test = pd.read_csv(test_file_path)

    # combine entire dataset
    combined_data_set_v0 = pd.concat([train, test])

    # append bus information
    combined_data_set_v1 = combined_data_set_v0.merge(other_bus_info, on="bus_no", how="left")

    # common preprocessing
    # 1. get year and month
    combined_data_set_v1.date = pd.to_datetime(combined_data_set_v1.date, format='%Y-%m-%d')
    combined_data_set_v1['year'] = pd.DatetimeIndex(combined_data_set_v1.date).year
    combined_data_set_v1['month'] = pd.DatetimeIndex(combined_data_set_v1.date).month
    # 2. drop unnecessary columns
    combined_data_set_v1 = combined_data_set_v1.drop(columns = ["date", "empl_id", 'bus_no', 'day_of_year', 'year'])

    # Prepare training and target columns
    X = combined_data_set_v1.drop(columns='incident')
    y = combined_data_set_v1['incident']

    # preprocessing with categorical features
    for c in X.columns:
        col_type = X[c].dtype
        if col_type == 'object' or col_type.name == 'category':
            X[c] = X[c].astype('category')
    
    #open the final model from the given path      
    filename = model_file_path
    
    with open(filename, 'rb') as infile:
        best_estimator = pickle.load(infile)

    print(best_estimator)
    #fit the final model with the complete dataset
    best_estimator.fit(X, y)
    
    if not os.path.exists(path_out):
        os.makedirs(path_out)

    # Save the final fitted model for usage in interactive report
    filename = path_out + "/final_fitted.pickle"
    with open(filename, 'wb') as outfile:
        pickle.dump(best_estimator, outfile)

    # generate summary plot for interpretability
    
    feat_import = TreeExplainer(best_estimator).shap_values(X=X)
    class0 = pd.DataFrame(feat_import[0])
    class0.columns = X.columns
    
    class1 = pd.DataFrame(feat_import[1])
    class1.columns = X.columns
    
    # Save class1 shap scores for usage in interactive report
    class1.to_csv(path_out + "/class1_shap.csv")
    X.to_csv(path_out + "/full_data.csv")

if __name__ == "__main__":
    main(opt["--train_file_path"], opt["--bus_file_path"], opt["--test_file_path"],
        opt["--model_file_path"], opt["--path_out"])
