#!/bin/bash

set -e

# Import the settings from the common settings file
source ../../common/project_settings.sh

bash ../build/build.sh

# The tag la-ace-products:0.1 is set in the build file. 
# If you change it here, change it there to match. 
docker tag la-ace-products:0.1 "gcr.io/$PROJECT_NAME/products"

docker push "gcr.io/$PROJECT_NAME/products"

# Authenticate kubectl
gcloud container clusters get-credentials $PRODUCT_CLUSTER_NAME --zone $PROJECT_ZONE --project $PROJECT_NAME

# Create a secret from the service account JSON file.

# This is an easy way to create or update a secret.
# From some awesome internet person 
# https://stackoverflow.com/questions/45879498/how-can-i-update-a-secret-on-kuberenetes-when-it-is-generated-from-a-file
kubectl create secret generic service-account-file \
    --from-file=../app/secrets/service_account.json \
    --dry-run -o yaml | kubectl apply -f -


kubectl apply -f workload.yaml

kubectl apply -f service.yaml