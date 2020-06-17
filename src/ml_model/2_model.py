import pandas as pd
import numpy as np 
import datetime
import multiprocessing

from lightgbm import LGBMClassifier
from shap import TreeExplainer, summary_plot
from hyperopt import hp, tpe, Trials, fmin, STATUS_OK
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import roc_auc_score

# Join 
train = pd.read_csv("data/ml-model/train.csv")
other_bus_info = pd.read_csv("data/TransLink Raw Data/Bus_spec.csv")
columns_bus_info = ["bus_no", "asset_class", "asset_manufactmodel"]
other_bus_info = other_bus_info.loc[:, columns_bus_info]
train_with_bus = train.merge(other_bus_info, on="bus_no", how="left")

test = pd.read_csv("data/ml-model/test.csv")
test_with_bus = test.merge(other_bus_info, on="bus_no", how="left")

# Do some feature engineering

def preprocessor(X, newdata):

    train = X.copy()
    validation = newdata.copy()

    train['month'] = train['date'].apply(lambda x: datetime.datetime.strptime(x, "%Y-%m-%d").month)
    validation['month'] = validation['date'].apply(lambda x: datetime.datetime.strptime(x, "%Y-%m-%d").month)
    
    seasons_lookup = {
        1: "Winter",
        2: "Winter",
        3: "Winter",
        4: "Spring",
        5: "Spring",
        6: "Spring",
        7: "Summer",
        8: "Summer",
        9: "Summer",
        10: "Fall",
        11: "Fall",
        12: "Fall"}

    day_lookup = {
        0: "EM",
        1: "EM",
        2: "EM",
        3: "EM",
        4: "EM",
        5: "EM",
        6: "Morning",
        7: "Morning",
        8: "Morning",
        9: "Morning",
        10: "Morning",
        11: "Morning",
        12: "Afternoon",
        13: "Afternoon",
        14: "Afternoon",
        15: "Afternoon",
        16: "Afternoon",
        17: "Afternoon",
        18: "Evening",
        19: "Evening",
        20: "Evening",
        21: "Evening",
        22: "Evening",
        23: "Evening"
    }

    # Create seasonal variable and part of day variable
    train['season'] = [seasons_lookup[month] for month in train['month']]
    train['part_of_day'] = [day_lookup[hour] for hour in train['hour']]

    # Create seasonal variable and part of day variable
    validation['season'] = [seasons_lookup[month] for month in validation['month']]
    validation['part_of_day'] = [day_lookup[hour] for hour in validation['hour']]

    all_categorical = train.select_dtypes(include=['object']).columns.tolist()
    # all_categorical_catboost = [i for i in all_categorical if i not in ['date', 'bus_no', 'day_of_week', 'experience_category', 'city', 'bus_carry_capacity', 'season', 'part_of_day', 'month']]

    all_categorical_regular = [i for i in all_categorical if i not in ['date', 'bus_no']]
    all_categorical_regular.extend(['month', 'hour', 'bus_carry_capacity'])

    # # CatBoost encoder
    # catboost_encoder = ce.CatBoostEncoder(
    #     cols=all_categorical_catboost,
    #     random_state=200350623)

    # train = catboost_encoder.fit_transform(
    #     X=train,
    #     y=train['incident'])

    # validation = catboost_encoder.transform(
    #     X=validation)
    
    reverse_lookup_reg = {}
    # Integer encoding for LightGBM's built in handling of such features
    for variable in all_categorical_regular:
        train[variable] = train[variable].astype('category')
        reverse_lookup_reg[variable] = dict(enumerate(train[variable].cat.categories))
        train[variable] = train[variable].cat.codes

        validation[variable] = validation[variable].astype('category')
        validation[variable] = validation[variable].cat.codes

    # Log plus 1 transformation for some of the right skewed variables

    train['total_rain'] = [np.log1p(x) for x in train['total_rain']]
    train['total_snow'] = [np.log1p(x) for x in train['total_snow']]
    train['wind_spd'] = [np.log1p(x) for x in train['wind_spd']]

    validation['total_rain'] = [np.log1p(x) for x in validation['total_rain']]
    validation['total_snow'] = [np.log1p(x) for x in validation['total_snow']]
    validation['wind_spd'] = [np.log1p(x) for x in validation['wind_spd']]

    # Sqrt transformation for left skewed

    train['rel_hum'] = [np.sqrt(x) for x in train['rel_hum']]
    validation['rel_hum'] = [np.sqrt(x) for x in validation['rel_hum']]

    train = train.drop(columns=['date', 'total_precip', 'bus_no', 'empl_id'])
    validation = validation.drop(columns=['date', 'total_precip', 'bus_no', 'empl_id'])

    return {'train': train, 'newdata': validation, 'lookup_reg': reverse_lookup_reg}

def optimize_param(train, space, all_categorical, n_splits=5):

    bayes_trials = Trials()
    folds = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=200350623)
    def objective(space):
        
        # n_estimators is huge because we use early_stopping here!
        model = LGBMClassifier(
            n_estimators=5000,
            learning_rate=0.05,
            num_leaves=space['num_leaves'],
            max_depth=space['max_depth'],
            colsample_bytree=space['colsample_bytree'],
            reg_alpha=space['reg_alpha'],
            reg_lambda=space['reg_lambda'],
            subsample_freq=5,
            n_jobs=multiprocessing.cpu_count() - 2,
            objective='binary',
            random_state=200350623
        )

        auroc_scores = []
        best_iter = []
        for train_idx, val_idx in folds.split(X=train, y=train['incident']):
            X_train_temp = train.iloc[train_idx, :].drop(columns=['incident'])
            y_train_temp = train['incident'][train_idx]
            X_val_temp = train.iloc[val_idx, :].drop(columns=['incident'])
            y_val_temp = train['incident'][val_idx]

            model.fit(
                X=X_train_temp,
                y=y_train_temp,
                early_stopping_rounds=20,
                eval_set=[(X_val_temp, y_val_temp)],
                eval_metric='auc',
                verbose=50,
                feature_name=X_train_temp.columns.tolist(),
                categorical_feature=all_categorical
                )

            auroc_scores.append(
                model._best_score['valid_0']['auc']
            )
            
            best_iter.append(
                model.best_iteration_
            )
        
        return {'loss': -np.mean(auroc_scores), 'params': space, 'status': STATUS_OK, 'iterations': np.round(np.mean(best_iter), 0)}

    fmin(fn=objective, space=space, algo=tpe.suggest, max_evals=50, trials=bayes_trials, rstate=np.random.RandomState(200350623))
    return bayes_trials


preprocessor_trained = preprocessor(
    X=train_with_bus,
    newdata=test_with_bus)

train_set = preprocessor_trained['train']
test_set = preprocessor_trained['newdata']
all_categorical_regular = list(preprocessor_trained['lookup_reg'].keys())

space = {
    'max_depth': hp.choice('max_depth', np.arange(1, 15, dtype=int)),
    'colsample_bytree': hp.uniform('colsample_bytree', 0.15, 1),
    'reg_alpha': hp.uniform('reg_alpha', 0, 15),
    'num_leaves': hp.choice('num_leaves', np.arange(5, 500, dtype=int)),
    'reg_lambda': hp.uniform('reg_lambda', 0, 40)
    }

results = optimize_param(
    train=train_set,
    n_splits=10,
    space=space,
    all_categorical=all_categorical_regular)

best_model_params = results.best_trial['result']['params']
n_iter = results.best_trial['result']['iterations']

final_lgb = LGBMClassifier(
    n_estimators=int(n_iter),
    learning_rate=0.05,
    num_leaves=best_model_params['num_leaves'],
    max_depth=best_model_params['max_depth'],
    colsample_bytree=best_model_params['colsample_bytree'],
    reg_alpha=best_model_params['reg_alpha'],
    reg_lambda=best_model_params['reg_lambda'],
    subsample_freq=5,
    n_jobs=multiprocessing.cpu_count() - 2,
    objective='binary',
    random_state=200350623
)

final_lgb.fit(
    X=train_set.drop(columns=['incident']),
    y=train_set['incident'],
    feature_name=train_set.drop(columns=['incident']).columns.tolist(),
    categorical_feature=all_categorical_regular
)

train_scores = final_lgb.predict_proba(X=train_set.drop(columns=['incident']))
train_roc = roc_auc_score(y_true=train_set['incident'], y_score=train_scores[:, 1])

test_scores = final_lgb.predict_proba(X=test_set.drop(columns=['incident']))
test_roc = roc_auc_score(y_true=test_set['incident'], y_score=test_scores[:, 1])

feat_import = TreeExplainer(final_lgb).shap_values(X=train_set.drop(columns=['incident']))

summary_plot(feat_import, train_set.drop(columns=['incident']))

pd.DataFrame({
    'var': train_set.drop(columns=['incident']).columns.tolist(),
    'imp': final_lgb.feature_importances_
}).sort_values(by='imp', ascending=False)