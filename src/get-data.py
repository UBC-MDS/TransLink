"""This script downloads all of the data located in the AWS S3 bucket, given the proper
access key and secret key. Assumes that this script will be run from the root of the repository.

Usage: get-data.py --access_key=<access_key> --secret_key=<secret_key>

Options:
--access_key=<access_key>   The AWS access key providing access to the bucket.
--secret_key=<secret_key>   The AWS secret key providing access to the bucket.
"""

import boto3
import os
from docopt import docopt

# Code is largely adapted from user Shan
# on StackOverflow: https://stackoverflow.com/questions/31918960/boto3-to-download-all-files-from-a-s3-bucket/33350380#33350380

opt = docopt(__doc__)

def main(access_key, secret_key):
    """ 
    This function downloads all of the data in the S3 bucket, given
    an accesss key and secret key with the right access.
    
    Parameters
    ----------
    access_key: str
        The AWS access key.
    
    secret_key: str
        The AWS secret key.
    
    Returns
    ---------
    None
    
    Examples
    ---------
    main(
        access_key=MY_ACCESS_KEY,
        secret_key=MY_SECRET_KEY
    )
    """

    # Initiate S3 client
    s3 = boto3.client(
        's3',
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key
    )

    for item in s3.list_objects(Bucket='mds-capstone-assurance')['Contents']:

        if not item['Key'].endswith("/"):

            print("Downloading file:", item['Key'])
            s3.download_file(
                'mds-capstone-assurance',
                item['Key'],
                item['Key']
                )
        else:
            if not os.path.exists(item['Key']):
                os.makedirs(item['Key'])
    return

main(
    access_key=opt['--access_key'],
    secret_key=opt['--secret_key']
    )