#!/usr/bin/env python
# coding: utf-8

"""
This script is to generate machine learning model for predictive analysis


Usage: model_generator.py --train_file_path=<train_file_path> --bus_file_path=<bus_file_path> \
    --test_file_path=<test_file_path> --output_file_path=<output_file_path> 

Options:

--train_file_path=<train_file_path>     A file path containing train dataset.
--bus_file_path=<bus_file_path>     A file path containing other bus information.
--test_file_path=<test_file_path>     A file path containing train dataset.
--output_file_path=<output_file_path>       A file path to write the results.

"""

import numpy as np
import time
import pandas as pd
import datetime
import multiprocessing
# classifiers / models
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import ShuffleSplit
from sklearn.ensemble import RandomForestClassifier
from lightgbm import LGBMClassifier
from xgboost import XGBClassifier
from shap import TreeExplainer, summary_plot
# Preprocessors 
from sklearn.preprocessing import StandardScaler
from sklearn.preprocessing import OneHotEncoder
from sklearn.pipeline import Pipeline, FeatureUnion, make_pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer

# other
from sklearn.preprocessing import normalize
from sklearn.metrics import log_loss, accuracy_score, classification_report
from sklearn.metrics import confusion_matrix
from sklearn.metrics import plot_confusion_matrix
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split, GridSearchCV, RandomizedSearchCV, cross_val_score, StratifiedKFold, KFold
from docopt import docopt


opt = docopt(__doc__)

def fit_and_report(model, X, y, Xv, yv):
    """
    fits a model and returns train and validation scores
    
    Arguments
    ---------     
    model -- sklearn classifier model
        The sklearn model
    X -- numpy.ndarray        
        The X part of the train set
    y -- numpy.ndarray
        The y part of the train set
    Xv -- numpy.ndarray        
        The X part of the validation set
    yv -- numpy.ndarray
        The y part of the validation set       
    
    
    
   
    
    """
    model.fit(X, y)
    lr_probs = model.predict_proba(X)
    lr_probs = lr_probs[:, 1]
    lr_probs_val = model.predict_proba(Xv)
    lr_probs_val = lr_probs_val[:, 1]
    # calculate scores
    lr_auc = roc_auc_score(y, lr_probs)
    lr_auc_val = roc_auc_score(yv, lr_probs_val)
    scores = [lr_auc, lr_auc_val]      
    return scores

def add_expt_result(results_dict, model, train_score, test_score):
    '''
    '''
    results_dict.setdefault('model', []).append(model)
    results_dict.setdefault('train score', []).append(train_score)
    results_dict.setdefault('validation score', []).append(test_score)
    df = pd.DataFrame(results_dict)
    df = df.drop_duplicates()
    return df



def main(train_file_path, bus_file_path, test_file_path, output_file_path):



    train = pd.read_csv(train_file_path)
    other_bus_info = pd.read_csv(bus_file_path)
    columns_bus_info = ["bus_no", "asset_class", "asset_manufactmodel"]
    other_bus_info = other_bus_info.loc[:, columns_bus_info]
    train_with_bus = train.merge(other_bus_info, on="bus_no", how="left")
    train_with_bus.date= pd.to_datetime(train_with_bus.date, format = '%Y-%m-%d')
    train_with_bus['year'] = pd.DatetimeIndex(train_with_bus.date).year
    train_with_bus['month'] = pd.DatetimeIndex(train_with_bus.date).month
    train_with_bus = train_with_bus.drop(columns = ["date", "empl_id", 'bus_no', 'day_of_year'])


    test = pd.read_csv(test_file_path)
    test_with_bus = test.merge(other_bus_info, on="bus_no", how="left")
    test_with_bus.date= pd.to_datetime(test_with_bus.date, format = '%Y-%m-%d')
    test_with_bus['year'] = pd.DatetimeIndex(test_with_bus.date).year
    test_with_bus['month'] = pd.DatetimeIndex(test_with_bus.date).month
    test_with_bus = test_with_bus.drop(columns = ["date", "empl_id", 'bus_no', 'day_of_year'])

    X = train_with_bus.drop(columns = 'incident')
    y = train_with_bus['incident']

    X_train, X_valid, y_train, y_valid = train_test_split(X, y,train_size=0.8, random_state=22)


    X_test = test_with_bus.drop(columns = 'incident')
    y_test = test_with_bus['incident']

    #preprocessing
    categorical_features = ['day_of_week', 'city', 'line_no', "asset_class", 'asset_manufactmodel', 'month']

    numeric_features = ['hour', 'bus_age', 'bus_carry_capacity', 'pressure', 'rel_hum', 'elev', 'temp', 'visib', 'wind_dir', 
                    'wind_spd', 'total_precip', 'total_rain', 'total_snow', 'year', 'experience_in_months']


    numeric_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy='median')),
        ('scaler', StandardScaler()) ])


    categorical_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy="most_frequent", fill_value='missing')),
        ('onehot', OneHotEncoder(sparse=False, handle_unknown='ignore')) ])
    preprocessor = ColumnTransformer(
                                    transformers=[
                                    ('num', numeric_transformer, numeric_features),
                                    ('cat', categorical_transformer, categorical_features)
                                ])

    # model selection 

    results_dict = {}
    models = {
        'logistic regression' : LogisticRegression(random_state = 1, solver = 'liblinear', C=1.0),       
        'random forest' : RandomForestClassifier(max_depth = 12), 
        'lgbm': LGBMClassifier(boosting_type="gbdt",random_state=10, num_leaves=30, max_depth=15, reg_lambda = 1.0, reg_alpha =0.0, eval_metric= 'auc', objective='binary',learning_rate=0.01)
            }

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


       

    param_opt = {
        'classifier__max_depth': [10, 20, 40],
        'classifier__num_leaves': [5, 15, 30],
        'classifier__reg_alpha': [0, 0.1, 1],
        'classifier__reg_lambda': [0, 0.1,1],
        'classifier__subsample': [0.8, 1], 
        'classifier__learning_rate' : [0.001, 0.1, 1]
    }
    model_f = LGBMClassifier(random_state= 123, objective= "binary")
    estimator = Pipeline(steps=[
            ('preprocessor', preprocessor),
            ('classifier', model_f)
        ])

    cv_folds = StratifiedKFold(n_splits=10, shuffle=True, random_state = 123)
    gridSearchCV = GridSearchCV(estimator =estimator , 
        param_grid = param_opt, 
        scoring='roc_auc',
        n_jobs=-1,
        cv=cv_folds,
        verbose=2)

    gridSearchCV.fit(X_train,y_train)

    #test with optimized lgbm

    t = time.time()
    scores  = fit_and_report(gridSearchCV.best_estimator_, X_train, y_train, X_valid, y_valid)
    elapsed_time = time.time() - t
    results = add_expt_result(results_dict, model_name + ' + optimized',  
                                            scores[0],  scores[1]) 


    results.to_csv(output_file_path, index=False)                                         

    #look at the most important features with shap and the original data
    for c in X.columns:
        col_type = X[c].dtype
        if col_type == 'object' or col_type.name == 'category':
            X[c] = X[c].astype('category')
        
    model_lgb = LGBMClassifier(
        learning_rate=gridSearchCV.best_params_['classifier__learning_rate'],
        num_leaves=gridSearchCV.best_params_['classifier__num_leaves'],
        max_depth=gridSearchCV.best_params_['classifier__max_depth'],
        reg_alpha=gridSearchCV.best_params_['classifier__reg_alpha'],
        subsample=gridSearchCV.best_params_['classifier__subsample']
    )
    model_lgb.fit(X, y)
    feat_import = TreeExplainer(model_lgb).shap_values(X=X)

    summary_plot(feat_import, X)

    original_features_importance = pd.DataFrame({
        'variables': X.columns.tolist(),
        'importance': model_lgb.feature_importances_
    }).sort_values(by='importance', ascending=False)

    original_features_importance.to_csv(output_file_path, index=False)

    # the same thing with preprocessing
    train_process = preprocessor.fit_transform(train_with_bus)
    feat_import = TreeExplainer(gridSearchCV.best_estimator_.named_steps['classifier']).shap_values(X=train_process )

    summary_plot(feat_import, train_process)

    features_with_importance = pd.DataFrame({
        'variables': numeric_features + gridSearchCV.best_estimator_.named_steps['preprocessor'].transformers_[1][1]\
    .named_steps['onehot'].get_feature_names(categorical_features).tolist(),
        'importance': gridSearchCV.best_estimator_.named_steps['classifier'].feature_importances_
    }).sort_values(by='importance', ascending=False)

    features_importance_with_onehot_encoding.to_csv(output_file_path, index=False)

if __name__ == "__main__":
    main(opt["--train_file_path"], opt["--bus_file_path"], opt["----test_file_path"], opt["--output_file_path"])

