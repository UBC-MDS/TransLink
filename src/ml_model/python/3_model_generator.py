#!/usr/bin/env python
# coding: utf-8

"""
This script fits the final model and generate results from this model for use in the report.
It takes train, test and bus information datasets and combines them to fit the final model.
It also takes the path for the final model and writes the results to the output file. 


Usage: 3_model_generator.py --train_file_path=<train_file_path> --bus_file_path=<bus_file_path> \
    --test_file_path=<test_file_path> --model_file_path=<model_file_path>



Options:

--train_file_path=<train_file_path>     A file path containing the train dataset.
--bus_file_path=<bus_file_path>     A file path containing other bus information.
--test_file_path=<test_file_path>     A file path containing the test dataset.
--model_file_path=<model_file_path>     A file path containing the final model selected from optimization.


Example:

python src/ml_model/python/model_generator.py --train_file_path "data/ml_model/train.csv"\
     --bus_file_path "data/TransLink Raw Data/Bus_spec.csv" --test_file_path  "data/ml_model/test.csv"\
         --model_file_path "results/ml_model/final_model_after_optimization.pickle"
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

def main(train_file_path, bus_file_path, test_file_path, model_file_path):

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
    infile = open(filename,'rb')

    #get the model
    best_estimator = pickle.load(infile)
    infile.close()
    print(best_estimator)
    #fit the final model with the complete dataset
    best_estimator.fit(X, y)
    
    # Save the final fitted model for usage in interactive report
    filename = "results/ml_model/final_fitted.pickle"
    outfile = open(filename, 'wb')
    pickle.dump(best_estimator, outfile)
    
    # generate summary plot for interpretability
    
    feat_import = TreeExplainer(best_estimator).shap_values(X=X)
    class0 = pd.DataFrame(feat_import[0])
    class0.columns = X.columns
    
    class1 = pd.DataFrame(feat_import[1])
    class1.columns = X.columns
    
    # Save class1 shap scores for usage in interactive report
    class1.to_csv("results/ml_model/class1_shap.csv")
    X.to_csv("results/ml_model/full_data.csv")

    # No longer needed since we recreate these plots in native R using the SHAP scores.
    # # onehot encoding for categorical features and standard scaling for numerical features
    # # impute to the missing values
    # categorical_features = ['day_of_week', 'city', 'line_no', "asset_class", 'asset_manufactmodel', 'month', 'is_shuttle']

    # numeric_features = ['hour', 'bus_age', 'bus_carry_capacity', 'pressure', 'rel_hum', 'elev', 'temp', 'visib', 'wind_dir', 
    #                     'wind_spd', 'total_precip', 'total_rain', 'total_snow', 'experience_in_months']

    # numeric_transformer = Pipeline(steps=[
    #     ('imputer', SimpleImputer(strategy='median')),
    #     ('scaler', StandardScaler())])


    # #create a pipeline for the model
    # categorical_transformer = Pipeline(steps=[
    #     ('imputer', SimpleImputer(strategy="most_frequent", fill_value='missing')),
    #     ('onehot', OneHotEncoder(sparse=False, handle_unknown='ignore'))])
    # preprocessor = ColumnTransformer(
    #                             transformers=[
    #                                 ('num', numeric_transformer, numeric_features),
    #                                 ('cat', categorical_transformer, categorical_features)
    #                             ])
    # estimator = Pipeline(steps=[
    #             ('preprocessor', preprocessor),
    #             ('classifier', best_estimator)
    #         ])
    # estimator.fit(X, y)
    # train_process = preprocessor.fit_transform(combined_data_set_v1)
    # features = numeric_features + estimator.named_steps['preprocessor'].transformers_[1][1]\
    # .named_steps['onehot'].get_feature_names(categorical_features).tolist()

    # feat_import = TreeExplainer(estimator.named_steps['classifier']).shap_values(X=train_process)
    # filename = "results/ml_model/tree_explainer_ohe.pickle"
    # outfile = open(filename,'wb')
    # pickle.dump({'shap_values': feat_import, 'X': train_process, 'feat_names': features}, outfile)
    # outfile.close()
    
    # summary_plot(feat_import, train_process, feature_names=features, class_inds=[1], show=False)
    # plt.savefig("results/ml_model/summary_plot_preprocessed_fetures.png", bbox_inches='tight')


if __name__ == "__main__":
    main(opt["--train_file_path"], opt["--bus_file_path"], opt["--test_file_path"],
        opt["--model_file_path"])
