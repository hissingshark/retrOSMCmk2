#!/bin/bash

# perform initial installation
function firstTimeSetup() {
    # get dependancies
    echo -e "\nInstalling required dependancies...\n"
    apt-get install -y git dialog || { echo "FAILED!"; exit; }
    echo -e "SUCCESS!\n\n"

    # get RetroPie-Setup
    echo -e "Installing RetroPie-Setup...\n"
    git submodule add https://github.com/RetroPie/RetroPie-Setup.git || { echo "FAILED!"; exit; }
    echo "SUCCESS!\n\n"

    # install EmulationStation launch service
    echo -e "Installing emulationstation.service...\n"
    cp scripts/emulationstation.service /etc/systemd/system/ || { echo "FAILED!"; exit; }
    systemctl daemon-reload || { echo "FAILED!"; exit; }
    echo -e "SUCCESS!\n\n"

    # install scripts into RetroPie directory
    # create it first if it doesn't exist - RetroPie-Setup wont remove it at install/update
    if [[ ! -d /home/osmc/RetroPie/scripts ]]; then
        mkdir -p /home/osmc/RetroPie/scripts
    fi
    cp scripts/* /home/osmc/RetroPie/scripts

    # not do this again
    first_run=0

    writeData
    return 0
}

# re-patch Retropie after an update
function patchRetroPie() {
    # PATCH 1
    # encapsulate the RetroPie update function with our own, so we get to repatch after they update
    # rename the original function away
    sed -i '/function updatescript_setup/s/updatescript_setup/updatescript_setup_original/' RetroPie-Setup/scriptmodules/admin/setup.sh
    # append our wrapper function
    cat resources/updatescript_setup.sh >> RetroPie-Setup/scriptmodules/admin/setup.sh

    # PATCH 2
    # use tvservice-shim instead of the real thing
    local runcommand_path
    if [[ -e  "/opt/retropie/supplementary/runcommand/runcommand.sh" ]]; then
        # working version patched in place
        runcommand_path="/opt/retropie/supplementary/runcommand/runcommand.sh"
    elif [[ -e "RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh" ]]; then
        # runcommand not installed yet, so patch the resource instead
        runcommand_path="RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh"
    else
        echo -e "FATAL ERROR!\nCannot patch runcommand.sh\nFile does not exist!\n"
        exit
    fi
    sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim\"/' $runcommand_path

    # PATCH 3
    # make binaries available for Vero4K
    sed -i '/__binary_host="/s/.*/__binary_host="hissingshark.co.uk"/' RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__has_binaries=/s/0/1/' RetroPie-Setup/scriptmodules/system.sh

    # we are up-to-date now
    patched_version=$retropie_version

    writeData

    return 0
}

# save variables to disk
function writeData() {
    cat << EOF > resources/data.sh
first_run=$first_run
retropie_version=$retropie_version
EOF
    return 0
}
