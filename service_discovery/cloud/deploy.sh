#!/bin/bash

# Import the settings from the common settings file
source ../../common/project_settings.sh

SOURCE_LOCAL_FOLDER="../app"


gcloud functions deploy service-discovery \
    --entry-point=index \
    --source=$SOURCE_LOCAL_FOLDER \
    --stage-bucket=$PRIVATE_ASSETS \
    --trigger-http
    --project=$PROJECT_NAME \
    --region=$PROJECT_REGION \