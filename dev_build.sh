#!/bin/sh

DEV="1"

if [ -z "$CLEAN" ]; then
CLEAN="0"
fi

if [ -z "$COREDIR" ]; then
COREDIR="./"
fi

DEV=$DEV CLEAN=$CLEAN COREDIR=$COREDIR ./build.sh

