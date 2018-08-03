#!/bin/bash

set -e

##############################################################################
#
# This only needs to be run once per project.
# This is going to create a new service account and download the
# key as a JSON file. 
# The account has bigtable user and storage write permissions 
#
##############################################################################

# Import the settings from the common settings file
source ../../common/project_settings.sh

cd ../build
bash build.sh

cd ../cloud
gsutil cp ../build/out/app gs://$PRIVATE_ASSETS/app

# Upload the initial ad image
gsutil cp juice.jpg gs://$PUBLIC_ASSETS/juice.jpg

# Insert a row to have some data
gcloud beta spanner rows insert \
    --instance=$PRODUCT_DB_INSTANCE_NAME \
    --database=$PRODUCT_DB_NAME \
    --table=ads \
    --data=AdID='first-ad',Company='Linux Academy',FileName='juice.jpg',Name='Juice Ad',PromisedViews=1000,TimesViewed=0,Timestamp='spanner.commit_timestamp()'

gcloud deployment-manager deployments create ad-service-deployment --config ads.yaml
