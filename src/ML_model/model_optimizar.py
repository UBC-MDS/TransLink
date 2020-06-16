#!/usr/bin/env python
# coding: utf-8

"""
This script is to prepare the train and test datasets to generate a predictive model. 
It compares different models to select the best one and then tune the best models' hyperparameters.
and it returns the best model as a pickled file.

Usage: model_optimizar.py --train_file_path=<train_file_path> --bus_file_path=<bus_file_path> \
    --test_file_path=<test_file_path>

Options:

--train_file_path=<train_file_path>     A file path containing train dataset.
--bus_file_path=<bus_file_path>     A file path containing other bus information.
--test_file_path=<test_file_path>     A file path containing train dataset.

"""
import numpy as np
import time
import pandas as pd
import datetime
# classifiers / models
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import ShuffleSplit
from sklearn.ensemble import RandomForestClassifier
from lightgbm import LGBMClassifier
from shap import TreeExplainer, summary_plot
# Preprocessors 
from sklearn.preprocessing import StandardScaler
from sklearn.preprocessing import OneHotEncoder
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer

# other
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score, StratifiedKFold
from docopt import docopt
import pickle

opt = docopt(__doc__)

def fit_and_report(model, X, y, X_valid, y_valid):
    """
    It fits a model and returns train and validation scores
    
    Parameters:
        
        model (sklearn classifier model): The sklearn model
        X (numpy.ndarray): The X part of the train set
        y (numpy.ndarray): The y part of the train set
        X_valid (numpy.ndarray): The X part of the validation set
        y_valid (numpy.ndarray): The y part of the validation set  
    
    Returns:
        scores (list): The list of scores of train and validation 
          
    
    """
    model.fit(X, y)
    lr_probs = model.predict_proba(X)
    lr_probs = lr_probs[:, 1]
    lr_probs_val = model.predict_proba(X_valid)
    lr_probs_val = lr_probs_val[:, 1]
    # calculate scores
    lr_auc = roc_auc_score(y, lr_probs)
    lr_auc_val = roc_auc_score(y_valid, lr_probs_val)
    scores = [lr_auc, lr_auc_val]      
    return scores

def add_expt_result(results_dict, model, train_score, test_score):
    '''

    It creates a dataframe that show the model scores.

    Parameters:
        
        results_dict (dict): The dictionary to store the scores
        model (sklearn classifier model): The sklearn model
        train_score (float): The traing score of the model
        test_score (float): The test score of the model

    Returns:
        df (dataFrame): The dataframe containing model scores.
       

    '''
    results_dict.setdefault('model', []).append(model)
    results_dict.setdefault('train score', []).append(train_score)
    results_dict.setdefault('validation score', []).append(test_score)
    df = pd.DataFrame(results_dict)
    df = df.drop_duplicates()
    return df

def main(train_file_path, bus_file_path, test_file_path):
    # load bus information
    other_bus_info = pd.read_csv(bus_file_path)

    # take only required columns
    columns_bus_info = ["bus_no", "asset_class", "asset_manufactmodel"]
    other_bus_info = other_bus_info.loc[:, columns_bus_info]

    # load train data and test data
    train = pd.read_csv(train_file_path)
    test = pd.read_csv(test_file_path)


    # merge bus information into train and test datasets
    train_with_bus = train.merge(other_bus_info, on="bus_no", how="left")
    test_with_bus = test.merge(other_bus_info, on="bus_no", how="left")

    # crate month column
    train_with_bus.date = pd.to_datetime(train_with_bus.date, format='%Y-%m-%d')
    test_with_bus.date = pd.to_datetime(test_with_bus.date, format='%Y-%m-%d')
    train_with_bus['month'] = pd.DatetimeIndex(train_with_bus.date).month
    test_with_bus['month'] = pd.DatetimeIndex(test_with_bus.date).month

    # drop unnecessary columns
    train_with_bus = train_with_bus.drop(columns = ["date", "empl_id", 'bus_no', 'day_of_year'])
    test_with_bus = test_with_bus.drop(columns = ["date", "empl_id", 'bus_no', 'day_of_year'])



    X = train_with_bus.drop(columns='incident')
    y = train_with_bus['incident']

    X_test = test_with_bus.drop(columns='incident')
    y_test = test_with_bus['incident']

    #split the train dataset to get validation dataset
    X_train, X_valid, y_train, y_valid = train_test_split(X, y,train_size=0.8, random_state=22)


    # onehot encoding for categorical features and standard scaling for numerical features
    # impute to the missing values
    categorical_features = ['day_of_week', 'city', 'line_no', "asset_class", 'asset_manufactmodel', 'month', 'is_shuttle']

    numeric_features = ['hour', 'bus_age', 'bus_carry_capacity', 'pressure', 'rel_hum', 'elev', 'temp', 'visib', 'wind_dir', 
                    'wind_spd', 'total_precip', 'total_rain', 'total_snow', 'experience_in_months']

    numeric_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy='median')),
        ('scaler', StandardScaler())])


    #create a pipeline for the model
    categorical_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy="most_frequent", fill_value='missing')),
        ('onehot', OneHotEncoder(sparse=False, handle_unknown='ignore'))])
        preprocessor = ColumnTransformer(
                                transformers=[
                                ('num', numeric_transformer, numeric_features),
                                ('cat', categorical_transformer, categorical_features)
                            ])

    # model selection 

    results_dict = {}

    models = {
    'logistic regression' : LogisticRegression(random_state = 123,  C=1.0),       
    'random forest' : RandomForestClassifier(max_depth = 12, random_state = 123), 
    'lgbm': LGBMClassifier(boosting_type="gbdt",random_state=123, num_leaves=30,
        max_depth=15, reg_lambda = 1.0, reg_alpha =0.0, eval_metric= 'auc', 
        objective='binary',learning_rate=0.01)
        }


    # compare the training and validation scores from different models
    for model_name, model in models.items():
    print('Training classifier ', model_name)
    t = time.time()
    clf = Pipeline(steps=[('preprocessor', preprocessor),
                        ('classifier', model)])

    tr_sc, valid_sc = fit_and_report(clf, X_train, y_train, X_valid, y_valid)
    elapsed_time = time.time() - t
    results_df = add_expt_result(results_dict, 
                                        model_name + ' + scaling',  
                                        tr_sc,  valid_sc)
    elapsed_time = time.time() - t    
    print("The classifier %s took %.2f s to train" %(model_name, elapsed_time))

    # write the results for future reference

    print(results_df)


    #lightgbm optimization procedure
    param_opt = {
        'classifier__max_depth': [10, 20, 40],
        'classifier__num_leaves': [5, 15, 30],
        'classifier__reg_alpha': [0, 0.1, 1],
        'classifier__reg_lambda': [0, 0.1,1],
        'classifier__subsample': [0.8, 1], 
        'classifier__learning_rate' : [0.001, 0.01, 0.1, 1]
        }

    #apply the pipeline
    model_lgbm = LGBMClassifier(random_state=123, objective= "binary")

    estimator = Pipeline(steps=[
        ('preprocessor', preprocessor),
        ('classifier', model_lgbm)
    ])

    #to get the best parameters apply grid search
    cv_folds = StratifiedKFold(n_splits=10, shuffle=True, random_state=123)

    gridSearchCV = GridSearchCV(estimator =estimator , 
        param_grid = param_opt, 
        scoring='roc_auc',
        n_jobs=-1,
        cv=cv_folds,
        verbose=2)

    #use all training dataset to get best parameters

    gridSearchCV.fit(X,y) 

    #see the test scores 

    lr_probs_test = gridSearchCV.best_estimator_.predict_proba(X_test)
    lr_probs_test = lr_probs_test[:, 1]
    lr_auc_test = roc_auc_score(y_test, lr_probs_test)
    print(lr_auc_test)

    # write final model 
    final_model =  LGBMClassifier(
        learning_rate=gridSearchCV.best_params_['classifier__learning_rate'],
        num_leaves=gridSearchCV.best_params_['classifier__num_leaves'],
        max_depth=gridSearchCV.best_params_['classifier__max_depth'],
        reg_alpha=gridSearchCV.best_params_['classifier__reg_alpha'],
        subsample=gridSearchCV.best_params_['classifier__subsample']
        )
    filename = 'results/ml_model/final_model_after_optimization'
    outfile = open(filename,'wb')
    pickle.dump(final_model, outfile)
    outfile.close()

if __name__ == "__main__":
    main(opt["--train_file_path"], opt["--bus_file_path"], opt["--test_file_path"])
