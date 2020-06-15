import numpy as np
import pandas as pd

# Classifiers / Models
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from lightgbm import LGBMClassifier

# Preprocessors 
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer

# Other
from sklearn.metrics import roc_auc_score
from hyperopt import hp, tpe, Trials, fmin, STATUS_OK
from sklearn.model_selection import StratifiedKFold
from docopt import docopt


train_set = pd.read_csv("data/ml-model/train.csv")
test_set = pd.read_csv("data/ml-model/test.csv")

other_bus_info = pd.read_csv("data/TransLink Raw Data/Bus_spec.csv")
columns_bus_info = ["bus_no", "asset_class", "asset_manufactmodel"]
other_bus_info = other_bus_info.loc[:, columns_bus_info]
train_with_bus = train_set.merge(other_bus_info, on="bus_no", how="left")
train_with_bus.date = pd.to_datetime(train_with_bus.date, format='%Y-%m-%d')
train_with_bus['month'] = pd.DatetimeIndex(train_with_bus.date).month
train_with_bus = train_with_bus.drop(columns=["date", "empl_id", 'bus_no', 'day_of_year'])

test_with_bus = test_set.merge(other_bus_info, on="bus_no", how="left")
test_with_bus.date = pd.to_datetime(test_with_bus.date, format='%Y-%m-%d')
test_with_bus['month'] = pd.DatetimeIndex(test_with_bus.date).month
test_with_bus = test_with_bus.drop(columns=["date", "empl_id", 'bus_no', 'day_of_year'])

all_features = set(train_with_bus.columns)
all_features.remove('incident')

categorical_features = set({'day_of_week',
                            'city',
                            'line_no',
                            "asset_class",
                            'asset_manufactmodel',
                            'is_shuttle',
                            'month'})

numeric_features = list(all_features - categorical_features)
categorical_features = list(categorical_features)

numeric_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy='median')),
        ('scaler', StandardScaler())])

categorical_transformer = Pipeline(steps=[
     ('imputer', SimpleImputer(strategy="most_frequent", fill_value='missing')),
     ('onehot', OneHotEncoder(sparse=False, handle_unknown='ignore'))])

preprocessor = ColumnTransformer(transformers=[
    ('num', numeric_transformer, numeric_features),
    ('cat', categorical_transformer, categorical_features)],
    remainder='passthrough')

def optimize_param(train, model_name, preprocessor, n_splits=10):

    bayes_trials = Trials()
    folds = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=200350623)
    
    # n_estimators is huge because we use early_stopping here!
        
    all_spaces = {
        'logistic regression': {'C': hp.uniform('C', 1e-6, 1e+6)},
        'random forest': {'max_depth': hp.choice('max_depth', np.arange(1, 25, dtype=int))},
        'lgbm': {
            'max_depth': hp.choice('max_depth', np.arange(1, 40, dtype=int)),
            'reg_alpha': hp.uniform('reg_alpha', 0, 1),
            'num_leaves': hp.choice('num_leaves', np.arange(5, 30, dtype=int)),
            'reg_lambda': hp.uniform('reg_lambda', 0, 1),
            'subsample': hp.uniform('subsample', 0.6, 1)
                }
            }
        
    space = all_spaces[model_name]
    
    def objective(space):

        if model_name == 'logistic regression':
            model = LogisticRegression(random_state=200350623, max_iter=5000, C=space['C'])
        elif model_name == 'random forest':
            model = RandomForestClassifier(space['max_depth'], random_state=200350623), 
        else:
            model = LGBMClassifier(
            n_estimators=5000,
            learning_rate=0.05,
            num_leaves=space['num_leaves'],
            max_depth=space['max_depth'],
            reg_alpha=space['reg_alpha'],
            subsample=space['subsample'],
            reg_lambda=space['reg_lambda'],
            n_jobs=-1,
            objective='binary',
            random_state=200350623)
        
        auroc_scores = []
        best_iter = []
        for train_idx, val_idx in folds.split(X=train, y=train['incident']):
            X_train_temp = train.iloc[train_idx, :].drop(columns=['incident'])
            y_train_temp = train['incident'][train_idx]
            X_val_temp = train.iloc[val_idx, :].drop(columns=['incident'])
            y_val_temp = train['incident'][val_idx]
            
            X_train_processed = preprocessor.fit_transform(X=X_train_temp)
            X_val_processed = preprocessor.transform(X=X_val_temp)
            
            if model_name == 'lgbm':
                model.fit(
                    X=X_train_processed,
                    y=y_train_temp,
                    early_stopping_rounds=20,
                    eval_set=[(X_val_processed, y_val_temp)],
                    eval_metric='auc',
                    verbose=50
                    )
                
                auroc_scores.append(model._best_score['valid_0']['auc'])
                best_iter.append(model.best_iteration_)
            
            else:
                model.fit(
                    X=X_train_processed,
                    y=y_train_temp
                    )
                
                auroc_score = roc_auc_score(
                    y_true=y_val_temp,
                    y_score=model.predict_proba(X=X_val_processed)[:, 1])
                auroc_scores.append(auroc_score)

        return {'loss': -np.mean(auroc_scores), 'params': space, 'status': STATUS_OK, 'iterations': np.round(np.mean(best_iter), 0)}

    fmin(fn=objective, space=space, algo=tpe.suggest, max_evals=50, trials=bayes_trials, rstate=np.random.RandomState(200350623))
    return bayes_trials

results_lr = optimize_param(train=train_with_bus, model_name='logistic regression', preprocessor=preprocessor, n_splits=5)
