#!/bin/sh

DEV="1"

if [ -z "$CLEAN" ]; then
CLEAN="0"
fi

DEV=$DEV CLEAN=$CLEAN ./build.sh

