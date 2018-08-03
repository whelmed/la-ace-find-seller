#!/bin/bash

# Import the settings from the common settings file
source ../project_settings.sh

gsutil mb -p $PROJECT_NAME -c regional -l $PROJECT_REGION gs://$PRIVATE_ASSETS/