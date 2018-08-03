#!/bin/bash

set -e

# Import the settings from the common settings file
source ../project_settings.sh


gcloud compute networks create $SERVICES_NETWORK \
    --project=$PROJECT_NAME \
    --description="A custom network for the product and ads services" \
    --subnet-mode=custom

gcloud beta compute networks subnets create $PRODUCT_SUBNET \
    --project=$PROJECT_NAME \
    --network=$SERVICES_NETWORK \
    --region=us-central1 \
    --range=10.29.0.0/24 \
    --enable-private-ip-google-access \
    --enable-flow-logs

gcloud beta compute networks subnets create $ADS_SUBNET \
    --project=$PROJECT_NAME \
    --network=$SERVICES_NETWORK \
    --region=us-central1 \
    --range=10.28.0.0/24 \
    --enable-private-ip-google-access \
    --enable-flow-logs


# Create firewall rules to allow the instances to be reachable to each other.
gcloud compute firewall-rules create "$SERVICES_NETWORK-internal-access" \
    --network $SERVICES_NETWORK \
    --allow tcp,udp,icmp \
    --source-ranges 10.28.0.0/15


gcloud compute firewall-rules create "$SERVICES_NETWORK-ssh" \
    --network $SERVICES_NETWORK \
    --allow tcp:22