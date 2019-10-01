#!/bin/bash

function cleanup()
{
        clear
        systemctl start mediacenter
}

systemctl stop mediacenter
sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
sudo sh -c 'fbset -g 1920 1080 1920 2160 32'
chvt 1
trap cleanup EXIT
sudo -u osmc /usr/bin/emulationstation
cleanup
