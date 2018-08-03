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

gcloud spanner instances create $PRODUCT_DB_INSTANCE_NAME \
    --description="Product database instance" \
    --config=regional-$PROJECT_REGION \
    --nodes=1

gcloud spanner databases create $PRODUCT_DB_NAME \
    --instance=$PRODUCT_DB_INSTANCE_NAME

gcloud spanner databases ddl update $PRODUCT_DB_NAME --instance=$PRODUCT_DB_INSTANCE_NAME \
    --ddl='CREATE TABLE ads (AdID STRING(MAX) NOT NULL, Company STRING(MAX) NOT NULL, FileName STRING(MAX) NOT NULL, Name STRING(MAX) NOT NULL,PromisedViews INT64 NOT NULL,Timestamp TIMESTAMP OPTIONS (allow_commit_timestamp=true),TimesViewed INT64 NOT NULL,) PRIMARY KEY (AdID)'


cat > ads.yaml << EOL
imports:
- path: instance.jinja
- path: autoscaler.jinja
- path: loadbalancer.jinja

resources:
- name: ads-deployment-instances
  type: instance.jinja
  properties:
    region: $PROJECT_REGION
    zone: $PROJECT_ZONE
    prefix: ads-service
    privateBucket: $PRIVATE_ASSETS
    publicBucket: $PUBLIC_ASSETS
    spannerDatabase: $PRODUCT_DB_NAME
    spannerInstance: $PRODUCT_DB_INSTANCE_NAME
    network: $SERVICES_NETWORK
    subnet: $ADS_SUBNET
    projectID: $PROJECT_NAME
    adBinName: app
    serviceAccount: $COMPUTE_ENGINE_SERVICE_ACCOUNT


- name: ads-deployment-autoscaler
  type: autoscaler.jinja
  properties:
    zone: $PROJECT_ZONE
    prefix: ads-service
    privateBucket: $PRIVATE_ASSETS
    projectID: $PROJECT_NAME
    adBinName: app
    size: 1
    maxSize: 2

- name: ads-deployment-loadbalancer
  type: loadbalancer.jinja
  properties:
    prefix: ads-service
    network: $SERVICES_NETWORK
    projectID: $PROJECT_NAME
EOL