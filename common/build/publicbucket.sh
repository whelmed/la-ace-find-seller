#!/bin/bash

# Import the settings from the common settings file
source ../project_settings.sh

cat > publicbucketcors.json << EOL
[
    {
      "origin": ["*"],
      "responseHeader": ["Content-Type", "Access-Control-Allow-Origin"],
      "method": ["GET", "HEAD"],
      "maxAgeSeconds": 5
    }
]
EOL

gsutil mb -p $PROJECT_NAME -c regional -l $PROJECT_REGION gs://$PUBLIC_ASSETS/

gsutil cors set publicbucketcors.json gs://$PUBLIC_ASSETS

gsutil iam ch allUsers:objectViewer gs://$PUBLIC_ASSETS
