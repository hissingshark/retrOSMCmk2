#!/bin/bash

function cleanup()
{
        clear
        systemctl start mediacenter
}

systemctl stop mediacenter
sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
chvt 1
trap cleanup EXIT
sudo -u osmc /usr/bin/emulationstation
cleanup
