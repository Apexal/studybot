#!/bin/bash

while true
do
	echo "STARTING BOT"
	./run & PID=$!
	sleep 10800
	kill $PID
	echo "KILLED BOT"
done
