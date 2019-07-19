#!/bin/bash


#############
# CONSTANTS #
#############

LOGO='retrOSMCmk2'
BACKTITLE="$LOGO - Installing RetroPie on your Vero4K"
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_ESC=255


###################
# SETUP FUNCTIONS #
###################

# perform initial installation
function firstTimeSetup() {
    # get dependancies
    echo -e "\nFirst time setup:\n\nInstalling required dependancies..."
    apt-get install -y git dialog || { echo "FAILED!"; exit 1; }
    echo -e "SUCCESS!\n"

    # get RetroPie-Setup
    # if present we only want update the installer, so leave it untouched
    if [[ ! -d submodule/RetroPie-Setup ]]; then
        echo "Installing RetroPie-Setup..."
        git -C submodule/ clone https://github.com/RetroPie/RetroPie-Setup.git || { echo "FAILED!"; exit 1; }
        echo "SUCCESS!\n"
    fi

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
    cp resources/launch.sh resources/tvservice-shim /home/osmc/RetroPie/scripts

    # install Emulationstation launching Kodi addon
    cp -r resources/script.launch.retropie /home/osmc/.kodi/addons/

    dialog \
      --backtitle "$BACKTITLE" \
      --title "INSTALLATION COMPLETE" \
      --msgbox "\
      \n$LOGO has just installed RetroPie and its Kodi addon for you.\
      \n\nPlease run RetroPie-Setup from the next menu to start installing your chosen emulators.\
      \n\nDon't forget to enable the RetroPie launcher in your Kodi Program Addons!\
      " 0 0

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
    # use tvservice-shim and fbset-shim instead of the real thing
    if [[ -e  "/opt/retropie/supplementary/runcommand/runcommand.sh" ]]; then
        # installed version patched in place
        # needs a fresh copy to work on, before we patch the original resource file
        cp submodule/RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh /opt/retropie/supplementary/runcommand/runcommand.sh
        sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim.sh\"\nshopt -s expand_aliases\nalias fbset=\"\/home\/osmc\/RetroPie\/scripts\/fbset-shim.sh\"/' /opt/retropie/supplementary/runcommand/runcommand.sh
    fi
    # patch the resource file regardless as there may be a re-install from there later
    sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim.sh\"\nshopt -s expand_aliases\nalias fbset=\"\/home\/osmc\/RetroPie\/scripts\/fbset-shim.sh\"/' submodule/RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh

    # PATCH 3
    # make binaries available for Vero4K
    sed -i '/__binary_host="/s/.*/__binary_host="hissingshark.co.uk"/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__has_binaries=/s/0/1/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__binary_url=/s/https/http/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/if ! isPlatform "rpi"; then/s/rpi/vero4k/' submodule/RetroPie-Setup/scriptmodules/supplementary/sdl2.sh
    sed -i '/if \[\[ "$__os_id" != "Raspbian" ]] && ! isPlatform "armv6"; then/,/fi/ d' submodule/RetroPie-Setup/scriptmodules/packages.sh

    return 0
}


##################
# MENU FUNCTIONS #
##################

#function menuManageRPS() {

#}

#function menuManageThis() {

#}


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
            --backtitle "$BACKTITLE" \
            --title "Setup Menu" \
            --clear \
            --cancel-label "Quit" \
            --item-help \
            --menu "Please select:" 0 0 6 \
            "1" "Run RetroPie-Setup" "Runs the RetroPie-Setup script." \
            "2" "Manage RetroPie-Setup" "Re-install, update or remove RetroPie-Setup." \
            "3" "Manage $LOGO" "Re-install, update or remove $LOGO (this installer!)." \
            "4" "Manage Launcher Addon" "Re-install, update or remove the Launcher Addon." \
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
                # Run RetroPie-Setup
                clear
                # launch RetroPie-Setup
                submodule/RetroPie-Setup/retropie_setup.sh
                ;;
            2 )
                # Reinstall RetroPie-Setup
                clear
                # remove and re-install and re-patch RetroPie-Setup
                # a simpe re-clone inadvertantly updates RPS unless we check which commit it was at before deleting it...
                rps_version=$(git log -C --pretty=format:'%H' -n 1)
                rm -r submodule/RetroPie-Setup
                firstTimeSetup
                git reset -C submodule/RetroPie-Setup --hard $rps_version
                patchRetroPie
                ;;
            3 )
                # Update (this installer)
                clear
                git reset --hard HEAD
                git pull
                firstTimeSetup
                # clean RetroPie-Setup ready for re-patching, but don't update it
                git reset -C submodule/RetroPie-Setup --hard HEAD
                patchRetroPie
                ;;
            4 )
                ;;
            5 )
                ;;
            6 )
                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "HELP" \
                  --msgbox "\
                    \nPlease run RetroPie-Setup from the menu to install/update/remove your chosen emulators.\
                    \n\nDon't forget to enable the RetroPie launcher in your Kodi Program Addons!\
                    " 0 0
                ;;
        esac
    done

# the end - get back to whence we came
popd >/dev/null
