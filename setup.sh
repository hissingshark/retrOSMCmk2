#!/bin/bash

# check we are running as root for all of the install work
if [ "$EUID" -ne 0 ]; then
    echo -e "\n***\nPlease run as sudo.\nThis is needed for installing any dependencies as we go and for running RetroPie-Setup.\n***"
    exit 1
fi

# all operations performed relative to this script
pushd $(dirname "${BASH_SOURCE[0]}") >/dev/null

# load variables and functions
. ./resources/data.sh
. ./resources/functions.sh

# constants
LOGO='retrOSMCmk2'
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_ESC=255

# perform initial setup if this is the 1st run
if [[ first_run -eq 1 ]]; then
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
