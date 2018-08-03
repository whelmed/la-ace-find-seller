#!/bin/bash

gcloud config set project ace-demo-2

# Build common service first.
cd common/build

# Enable the APIs
bash enableapis.sh

# Create the network used for Kubernetes and Compute Engine.
bash network.sh

# Create the public and private buckets
bash privatebucket.sh
bash publicbucket.sh

# Create the pubsub topic 
bash pubsub.sh

# Create the bigtable instance
bash bigtable.sh

# Create the bigquery table based on the Bigtable schema.
bash bigquery.sh


# Setup and deploy the product service.
cd ../../products/cloud
bash setup.sh
cd ../deploy
bash deploy.sh


# Setup the ads
cd ../../ads/cloud
bash setup.sh
bash deploy.sh


# Setup the cloud function app that listens to pubsub and handles image processing.
cd ../../image_parser/deploy
bash deploy.sh


# Setup the front-end app
cd ../../frontend/cloud
bash setup.sh

source common/project_settings.sh

echo "Have you setup the urls and environment variables for the frontend app?"
echo "Set the APP_TOPIC environment variable to $PUB_SUB_TOPIC"
echo "Set the host on line 5 in the items.js file to http://$(kubectl get svc -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')/"
echo "Set the host on line 8 in the items.js file to http://$(gcloud compute forwarding-rules list --filter='name:"ads-service-forwarding-rules"' --format='value(IPAddress)')/"

while true; do
    read -p "Are you ready to continue? (Y or N): " yn
    case $yn in
        [Yy]* ) bash deploy.sh; break;;
        [Nn]* ) break;;
        * ) echo "Type y or n";;
    esac
done

