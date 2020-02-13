#!/bin/bash

# Import the settings from the common settings file
source ../../common/project_settings.sh

export GOPATH="$(dirname $PWD)/vendor"

# Build the code into the vendor dir.
bash ../build/build.sh

GOPATH="$(dirname "$PWD")/vendor" gcloud app deploy $GOPATH/src/github.com/linuxacademy/frontend/app.yaml -q
