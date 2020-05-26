#!/bin/bash

mkdir -p $GOPATH/src/github.com/linuxacademy/frontend

cp -R /code/* $GOPATH/src/github.com/linuxacademy/frontend

cd $GOPATH/src/github.com/linuxacademy/frontend

go get . 

# There's a strange issue, that I don't have time to deal with.
rm -fr $GOPATH/src/github.com/valyala/fasttemplate/vendor

go get .


