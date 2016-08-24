#!/bin/sh
#
# ./script/presizely prefork -m production -w 32 -c 8 -P /tmp/presizely.pid -l http://*:3000?reuse=1
./script/presizely prefork -m production -w 16 -c 2 &
