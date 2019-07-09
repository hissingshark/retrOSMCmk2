#!/bin/bash

# perform initial installation
function firstTimeSetup() {
    # get dependancies
    echo  "\nInstalling required dependancies..."
    apt-get install -y git dialog || { echo "FAILED!"; exit 1; }
    echo -e "SUCCESS!\n"

    # get RetroPie-Setup
    echo "Installing RetroPie-Setup..."
#    git submodule add https://github.com/RetroPie/RetroPie-Setup.git || { echo "FAILED!"; exit; }
    git -C submodule/ clone https://github.com/RetroPie/RetroPie-Setup.git || { echo "FAILED!"; exit 1; }
    echo "SUCCESS!\n"

    # install EmulationStation launch service
    echo "Installing emulationstation.service..."
    cp scripts/emulationstation.service /etc/systemd/system/ || { echo "FAILED!"; exit 1; }
    systemctl daemon-reload || { echo "FAILED!"; exit 1; }
    echo -e "SUCCESS!\n"

    # install scripts into RetroPie directory
    # create it first if it doesn't exist - RetroPie-Setup wont remove it at install/update
    if [[ ! -d /home/osmc/RetroPie/scripts ]]; then
        mkdir -p /home/osmc/RetroPie/scripts
    fi
    cp scripts/launcher.sh scripts/tvservice-shim /home/osmc/RetroPie/scripts

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
    sed -i '/function updatescript_setup()/s/updatescript_setup/updatescript_setup_original/' submodule/RetroPie-Setup/scriptmodules/admin/setup.sh
    # append our wrapper function
    cat resources/updatescript_setup.sh >> submodule/RetroPie-Setup/scriptmodules/admin/setup.sh

    # PATCH 2
    # use tvservice-shim instead of the real thing
    if [[ -e  "/opt/retropie/supplementary/runcommand/runcommand.sh" ]]; then
        # installed version patched in place
        sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim\"/' /opt/retropie/supplementary/runcommand/runcommand.sh
    fi
    # patch the resource file regardless as there may be a re-install from there later
    sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim\"/' submodule/RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh

    # PATCH 3
    # make binaries available for Vero4K
    sed -i '/__binary_host="/s/.*/__binary_host="hissingshark.co.uk"/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__has_binaries=/s/0/1/' submodule/RetroPie-Setup/scriptmodules/system.sh

    return 0
}

# save variables to disk
function writeData() {
    cat << EOF > resources/data.sh
first_run=$first_run
EOF
    return 0
}
