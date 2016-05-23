#!/bin/bash

trap 'kill -TERM $PID' TERM INT

for i in {1..200}
do
echo "spawning client $i"
node client.js &
done

PID=$!
wait $PID
trap - TERM INT
wait $PID
EXIT_STATUS=$?
