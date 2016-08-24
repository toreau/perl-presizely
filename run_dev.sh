#!/bin/sh
#
MOJO_MAX_MESSAGE_SIZE=33554432 ./script/presizely prefork -m development -w 8 -c 2 -P /tmp/presizely.pid -l http://*:3000?reuse=1
