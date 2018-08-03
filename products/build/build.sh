#!/bin/bash

# The final ../ sets the context for this to be the parent dir.
# This is important because it ensures the Dockerfile can see the app dir.

# If you change the tag of la-ace-products:0.1 then edit the build.sh for this service too. 
# Just do a find and replace for "la-ace-products:0.1"
docker build -t la-ace-products:0.1 -f "$(dirname "$0")/Dockerfile" "$(dirname "$0")/../"