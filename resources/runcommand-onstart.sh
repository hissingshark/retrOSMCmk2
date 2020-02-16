#!/bin/bash

platform=$1

rom=${3##*/}
rom=${rom%.*}

echo "update $platform $rom" > /tmp/app-switcher.fifo
