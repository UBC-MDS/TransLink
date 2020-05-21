# Pull in data from S3. Replace ... with your access key and secret key.

data/TransLink\ Raw\ Data/2020\ Collisions-\ Preventable\ and\ Non\ Preventable\ UBC\ Set\ Without\ Claim\ Number.xlsx data/TransLink\ Raw\ Data/claim_vehicle_employee_line.csv data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx data/TransLink\ Raw\ Data/pedestrain_claims.csv data/TransLink\ Raw\ Data/preventable_NonPreventable_claims.csv data/TransLink\ Raw\ Data/Speed\ performance\ data.csv: src/get-data.py
    python src/get-data.py --access_key=... --secret_key=...

# -----------------------------Operators Analysis---------------------#

# Wrangle the data, split into train and test

data/operators/train.csv data/operators/test.csv: src/operators/wrangle.R data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx
    Rscript src/operators/wrangle.R data/TransLink\ Raw\ Data/Operator\ With\ Incident\ Last\ 3\ Years.xlsx data/operators


