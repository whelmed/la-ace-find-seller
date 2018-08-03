#!/bin/bash

set -e

##############################################################################
#
# This only needs to be run once per project.
# This is going to create a new service account and download the
# key as a JSON file. 
# The account has only pub/sub publisher permissions
# because that's all this app needs!
#
##############################################################################

# Import the settings from the common settings file
source ../../common/project_settings.sh
##############################################################################
#
# Create an app engine app. Once created
# the region cannot be changed. 
# So if you mess up, you'll need a new project.
#
##############################################################################
gcloud app create --project=$PROJECT_NAME --region=$APP_ENGINE_REGION -q