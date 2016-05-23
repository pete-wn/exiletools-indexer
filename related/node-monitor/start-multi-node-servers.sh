#!/bin/bash

trap 'kill -TERM $PID' TERM INT

node server.js 6001 &
node server.js 6002 &
node server.js 6003 &
node server.js 6004 &

PID=$!
wait $PID
trap - TERM INT
wait $PID
EXIT_STATUS=$?
