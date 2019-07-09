#!/bin/bash

#############
# constants #
#############

LOGO='retrOSMCmk2'
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_ESC=255

#############
# FUNCTIONS #
#############

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
    cp resources/emulationstation.service /etc/systemd/system/ || { echo "FAILED!"; exit 1; }
    systemctl daemon-reload || { echo "FAILED!"; exit 1; }
    echo -e "SUCCESS!\n"

    # install scripts into RetroPie directory
    # create it first if it doesn't exist - RetroPie-Setup wont remove it at install/update
    if [[ ! -d /home/osmc/RetroPie/scripts ]]; then
        mkdir -p /home/osmc/RetroPie/scripts
    fi
    cp resources/launcher.sh resources/tvservice-shim /home/osmc/RetroPie/scripts

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


#########################
# EXECUTION STARTS HERE #
#########################

# check we are running as root for all of the install work
if [ "$EUID" -ne 0 ]; then
    echo -e "\n***\nPlease run as sudo.\nThis is needed for installing any dependencies as we go and for running RetroPie-Setup.\n***"
    exit 1
fi

# all operations performed relative to this script
pushd $(dirname "${BASH_SOURCE[0]}") >/dev/null

# perform initial setup if this is the 1st run - determined by presence of RetroPie-Setup
if [[ ! -d submodule/RetroPie-Setup ]]; then
    firstTimeSetup
fi

# RetroPie-Setup will - post update - call this script specifically to restore the lost patches
if [[ "$1" == "PATCH" ]]; then
    patchRetroPie
    popd >/dev/null
    exit 0
fi

# RetroPie is not yet patched at fresh install, nor if something went wrong after an update
# ensure we aren't re-patching patched files.  Breakage may result!
[[ $(grep 'retrOSMC_Patched' submodule/RetroPie-Setup/scriptmodules/admin/setup.sh | wc -l) -eq 0 ]] && patchRetroPie

# dialog menu here
    while true; do
        exec 3>&1
        selection=$(dialog \
            --backtitle "$LOGO - Installing RetroPie-Setup on your Vero4K" \
            --title "Setup Menu" \
            --clear \
            --cancel-label "Quit" \
            --item-help \
            --menu "Please select:" 0 0 5 \
            "1" "Run RetroPie-Setup" "Runs the RetroPie-Setup script." \
            "1" "Reinstall RetroPie-Setup" "Reinstall the RetroPie-Setup script." \
            "2" "Update $LOGO" "Pulls the latest version of this $LOGO script from the repository." \
            "3" "Uninstall $LOGO" "Uninstalls this $LOGO script and RetroPie-Setup.  The emulators remain installed to avoid lost configs and wasted compilation.  Use RetroPie-Setup to remove these." \
            "4" "Install launcher addon" "Installs an addon to launch Emulationstation directly from Kodi." \
            "5" "Help" "Some general explanations." \
            2>&1 1>&3)
        ret_val=$?
        exec 3>&-

        case $ret_val in
            $DIALOG_CANCEL)
                clear
                echo "Program quit."
                break
                ;;
            $DIALOG_ESC)
                clear
                echo "Program aborted."
                break
                ;;
        esac

        case $selection in
            0 )
                clear
                echo "Program terminated."
                break
                ;;
            1 )
                submodule/RetroPie-Setup/retropie_setup.sh
                ;;
            2 )
                ;;
            3 )
                ;;
            4 )
                ;;
        esac
    done

# the end - get back to whence we came
popd >/dev/null
