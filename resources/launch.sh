#!/bin/bash

function cleanup()
{
        clear
        systemctl start mediacenter
}

systemctl stop mediacenter
chvt 1
trap cleanup EXIT
sudo -u osmc /usr/bin/emulationstation
cleanup
