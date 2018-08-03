#!/bin/bash

# To see all the posible services...
# gcloud services list  --available --sort-by="NAME"

# To see all the enabled services...
# gcloud services list  --enabled --sort-by="NAME"

# Shared services
# Enable Storage.
gcloud services enable storage-component.googleapis.com
# Enable Bigtable.
gcloud services enable bigtable.googleapis.com
# Enable Stackdriver
gcloud services enable stackdriver.googleapis.com
# Enable Cloud SQL
gcloud services enable sql-component.googleapis.com
# Enable Datastore
gcloud services enable datastore.googleapis.com


# The frontend application
# Enable App Engine
gcloud services enable appengine.googleapis.com
# Enable Pubsub
gcloud services enable pubsub.googleapis.com

# Image processor
# Enable Cloud Vision API
gcloud services enable vision.googleapis.com
# Enable Cloud Functions
gcloud services enable cloudfunctions.googleapis.com

# The product application
# Enable Kubernetes Engine
gcloud services enable container.googleapis.com
# Enable Bigquery
gcloud services enable bigquery-json.googleapis.com
# Enable Container Registry
gcloud services enable containerregistry.googleapis.com 

# The ads application
# Enable Compute Engine
gcloud services enable compute.googleapis.com
# Enable Spanner
gcloud services enable spanner.googleapis.com  