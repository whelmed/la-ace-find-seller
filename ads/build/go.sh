#!/bin/bash

go get ./... 

# Build for Linux
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /build/out/app .
