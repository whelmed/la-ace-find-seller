#!/bin/bash

# Import the settings from the common settings file
source ../../common/project_settings.sh

SOURCE_LOCAL_FOLDER="../app"


gcloud beta functions deploy $FUNCTION_NAME \
    --entry-point=imageParser \
    --source=$SOURCE_LOCAL_FOLDER \
    --stage-bucket=$PRIVATE_ASSETS \
    --trigger-resource=$PUB_SUB_TOPIC \
    --trigger-event="google.pubsub.topic.publish" \
    --project=$PROJECT_NAME \
    --region=$PROJECT_REGION \
    --set-env-vars=BIGTABLE_INSTANCE_ID=$BIGTABLE_INSTANCE_ID,BIGTABLE_TABLE_ID=$BIGTABLE_TABLE_ID,CLOUD_STORAGE_BUCKET=$PUBLIC_ASSETS
