#!/bin/bash
if ! echo $* | egrep -qw "\-xres|\-yres|\-vxres|\-vyres|\-depth|\-g|\--geometry"
then
    /bin/fbset $@
fi
