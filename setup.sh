#!/bin/bash

. ./resources/data.sh
. ./resources/functions.sh

# check we are running as root for all of the install work
if [ "$EUID" -ne 0 ]; then
    echo -e "\n***\nPlease run as sudo.\nThis is needed for installing any dependancies as we go and for running RetroPie-Setup.\n***"
    exit
fi

if [[ first_run -eq 1 ]]; then
    firstTimeSetup
    patchRetroPie
elif [[ patched_version -ne $(git -C RetroPie-Setup/ log -1 --pretty=format:"%h") ]]; then
    patchRetroPie
fi
