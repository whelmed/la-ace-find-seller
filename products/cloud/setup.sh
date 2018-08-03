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

# This section of code is modified from the code found here:
# https://www.spinnaker.io/setup/install/providers/appengine/

# Ensure the secrets dir exists
mkdir -p ../app/secrets
# Create a new role for the app. 
SERVICE_ACCOUNT_NAME=product-service
SERVICE_ACCOUNT_DEST=../app/secrets/service_account.json

gcloud iam service-accounts create \
    $SERVICE_ACCOUNT_NAME \
    --display-name $SERVICE_ACCOUNT_NAME

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:$SERVICE_ACCOUNT_NAME" \
    --format='value(email)')

gcloud projects add-iam-policy-binding $PROJECT_NAME \
    --role roles/bigtable.user \
    --member serviceAccount:$SA_EMAIL

gcloud projects add-iam-policy-binding $PROJECT_NAME \
    --role roles/storage.objectAdmin \
    --member serviceAccount:$SA_EMAIL

gcloud projects add-iam-policy-binding $PROJECT_NAME \
    --role roles/bigquery.dataViewer \
    --member serviceAccount:$SA_EMAIL

gcloud projects add-iam-policy-binding $PROJECT_NAME \
    --role roles/bigquery.jobUser \
    --member serviceAccount:$SA_EMAIL

gcloud iam service-accounts keys create $SERVICE_ACCOUNT_DEST --iam-account $SA_EMAIL

echo "##############################################################################"
echo "Service account created and key stored in the products/app/secrets dir with the name $SERVICE_ACCOUNT_NAME"
echo "##############################################################################"
##############################################################################
#
# Create Kubernetes Cluster.  
# 
#
##############################################################################
gcloud beta container clusters create $PRODUCT_CLUSTER_NAME \
    --project $PROJECT_NAME \
    --zone $PROJECT_ZONE \
    --no-enable-basic-auth \
    --cluster-version "1.9.7-gke.3" \
    --machine-type "n1-standard-1" \
    --image-type "COS" \
    --disk-type "pd-standard" \
    --disk-size "100" \
    --num-nodes "3" \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --network $SERVICES_NETWORK \
    --subnetwork $PRODUCT_SUBNET \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,KubernetesDashboard \
    --enable-autoupgrade \
    --enable-autorepair \
    --service-account $SA_EMAIL


##############################################################################
#
# Push the container to the Google Cloud Container Registry.
# Kubernetes works with container images, not dockerfiles. 
# So we need to build the image and put it someplace that it can be accessed.
# 
##############################################################################
gcloud auth configure-docker -q

# This allows us to create the YAML file without needing to edit the variables for different projects.
cat > ../deploy/workload.yaml << EOL
---
apiVersion: "v1"
kind: "ConfigMap"
metadata:
  name: "products-service-config"
  namespace: "default"
  labels:
    app: "products-service"
data:
  # The path /sa comes from the volume mounted in the container.
  # It mounts the secret to that path.
  # The secret is created in the deploy.sh file for this service
  SERVICE_ACCOUNT_FILE_NAME: "/sa/service_account.json" 
  PROJECT_ID: "$PROJECT_NAME"
  PRODUCT_CACHE_BUCKET: "$PUBLIC_ASSETS"
---
apiVersion: "extensions/v1beta1"
kind: "Deployment"
metadata:
  name: "products-service"
  namespace: "default"
  labels:
    app: "products-service"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: "products-service"
  template:
    metadata:
      labels:
        app: "products-service"
    spec:
      containers:
      - name: "products"
        image: "gcr.io/$PROJECT_NAME/products:latest"
        volumeMounts:
        - name: service-account
          mountPath: "/sa/"
          readOnly: true
        env:
        - name: "SERVICE_ACCOUNT_FILE_NAME"
          valueFrom:
            configMapKeyRef:
              key: "SERVICE_ACCOUNT_FILE_NAME"
              name: "products-service-config"
        - name: "PROJECT_ID"
          valueFrom:
            configMapKeyRef:
              key: "PROJECT_ID"
              name: "products-service-config"
        - name: "PRODUCT_CACHE_BUCKET"
          valueFrom:
            configMapKeyRef:
              key: "PRODUCT_CACHE_BUCKET"
              name: "products-service-config"
      volumes:
      - name: service-account
        secret: 
            secretName: service-account-file
---
apiVersion: "autoscaling/v1"
kind: "HorizontalPodAutoscaler"
metadata:
  name: "products-service-hpa"
  namespace: "default"
  labels:
    app: "products-service"
spec:
  scaleTargetRef:
    kind: "Deployment"
    name: "products-service"
    apiVersion: "apps/v1beta1"
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
EOL