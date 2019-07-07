#!/bin/bash

# perform initial installation
function firstTimeSetup() {
    if [[ first_run -eq 1 ]]; then
        # get dependancies
        sudo apt-get install -f git dialog

        # obtain RetroPie
        git clone --recursive https://github.com/RetroPie/RetroPie-Setup.git

        # install EmulationStation launch service
        cp scripts/emulationstation.service /etc/systemd/system/
        systemctl daemon-reload

        # not do this again
        first_run=0
    fi
}

# re-patch Retropie after an update
function patchRetroPie() {
    # obtain current RetroPie commit
    local retropie_version=$(git -C RetroPie-Setup/ log -1 --pretty=format:"%h")

    # re-apply patches if RetroPie has been updated
    if [[ patched_version -ne $retropie_version ]]; then
        # PATCH 1
        # encapsulate the RetroPie update function with our own, so we get to repatch after they update
        # rename the original function away
        sed -i 'function updatescript_setup/s/updatescript_setup/updatescript_setup_original/' scriptmodules/admin/setup.sh
        # append our wrapper function
        cat scripts/updatescript_setup.sh >> scriptmodules/admin/setup.sh

        # PATCH 2
        # use tvservice-shim instead of the real thing
        local runcommand_path
        if [[ -e  "/opt/retropie/supplementary/runcommand/runcommand.sh" ]]; then
            # working version patched in place
            runcommand_path="/opt/retropie/supplementary/runcommand/runcommand.sh"
        elif [[ -e "./RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh" ]]; then
            # runcommand not installed yet, so patch the resource instead
            runcommand_path="./RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh"
        else
            echo -e "FATAL ERROR!\nCannot patch runcommand.sh\nFile does not exist!\n"
            exit
        fi
        sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"~\/retrOSMCmk2\/scripts\/tvservice-shim\"/' runcommand_path

        # PATCH 3
        # make binaries available for Vero4K

        # we are up-to-date now
        patched_version=retropie_version
    fi

    writeData

    return 0
}

# save variables to disk
function writeData() {
    cat << EOF > ./resources/data.sh
first_run=$first_run
retropie_version=$retropie_version
EOF
    return 0
}
