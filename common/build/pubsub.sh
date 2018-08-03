#!/bin/bash

# Import the settings from the common settings file
source ../project_settings.sh

gcloud pubsub topics create $PUB_SUB_TOPIC --project $PROJECT_NAME