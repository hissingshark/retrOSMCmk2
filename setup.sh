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
    depends=(git dialog pulseaudio evtest)
    if [[ "$platform" == "rpi" ]]; then
        depends+=(alsa-utils)
    fi
    apt-get install -y "${depends[@]}" || { echo "FAILED!"; exit 1; }
    clear
    dialog \
      --backtitle "$BACKTITLE" \
      --title "First Time Setup" \
      --infobox "\
      \nSUCCESS!\n\
      " 0 0
    sleep 2

    # get RetroPie-Setup
    # if present we only want update the installer, so leave it untouched
    if [[ ! -d submodule/RetroPie-Setup ]]; then
        dialog \
          --backtitle "$BACKTITLE" \
          --title "First Time Setup" \
          --infobox "\
          \nInstalling RetroPie-Setup...\n\
          " 0 0
        sleep 2
        su osmc -c -- 'git -C submodule/ clone https://github.com/RetroPie/RetroPie-Setup.git' || { echo "FAILED!"; exit 1; }
        clear
        dialog \
          --backtitle "$BACKTITLE" \
          --title "First Time Setup" \
          --infobox "\
          \nSUCCESS!\n\
          " 0 0
        sleep 2
    fi

    # start installing scripts and services
    dialog \
      --backtitle "$BACKTITLE" \
      --title "First Time Setup" \
      --infobox "\
      \nInstalling $LOGO scripts and services...\n\
      " 0 0
    sleep 2

    # install scripts into RetroPie directory
    # create it first if it doesn't exist - RetroPie-Setup wont remove it at install/update
    if [[ ! -d /home/osmc/RetroPie/scripts ]]; then
        mkdir -p /home/osmc/RetroPie/scripts
    fi
    cp resources/{app-switcher.sh,cec-exit.py,es-launch.sh,evdev-exit.py,evdev-helper.sh,fbset-shim.sh,tvservice-shim.sh} /home/osmc/RetroPie/scripts || { echo "FAILED!"; exit 1; }

    # install the retrOSMC Kodi addon
    cp -r resources/script.launch.retropie /home/osmc/.kodi/addons/ || { echo "FAILED!"; exit 1; }
    if [[ ! -d /home/osmc/.kodi/userdata/addon_data/script.launch.retropie ]]; then
        mkdir -p /home/osmc/.kodi/userdata/addon_data/script.launch.retropie
    fi

    # install and enable services
    cp resources/{app-switcher.service,cec-exit.service,evdev-exit.service,emulationstation.service} /etc/systemd/system/ || { echo "FAILED!"; exit 1; }
    systemctl daemon-reload || { echo "FAILED!"; exit 1; }
    systemctl enable app-switcher.service || { echo "FAILED!"; exit 1; }
    systemctl start app-switcher.service || { echo "FAILED!"; exit 1; }

    # perform RPi specific configuration
    if [[ "$platform" == "rpi" ]]; then
        # add fix to config.txt for sound
        if [[ ! $(grep "dtparam=audio=on" "/boot/config.txt") ]]; then
            sudo su -c 'echo -e "dtparam=audio=on" >> "/boot/config.txt"'
        fi
        # set the output volume
        amixer set PCM 100
    fi

    clear
    dialog \
      --backtitle "$BACKTITLE" \
      --title "First Time Setup" \
      --infobox "\
      \nSUCCESS!\n\
      " 0 0
    sleep 2

    clear
    dialog \
      --backtitle "$BACKTITLE" \
      --title "INSTALLATION COMPLETE" \
      --msgbox "\
      \n$LOGO has just installed RetroPie and its Kodi addon for you.\
      \n\nPlease run RetroPie-Setup from the next menu to start installing your chosen emulators.\
      \n\nDon't forget to enable the RetroPie launcher in your Kodi Program Addons! (a reboot may be required for it to be listed there)\
      " 0 0

    return 0
}

# re-patch Retropie after an update
function patchRetroPie() {
    # ignore patches for RPi series
    if [[ "$platform" == "rpi" ]]; then
        return 0
    fi

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
    sed -i '/__binary_host="/s/.*/__binary_host="download.osmc.tv\/dev\/hissingshark"/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__has_binaries=/s/0/1/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__binary_url=/s/https/http/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/if ! isPlatform "rpi"; then/s/rpi/vero4k/' submodule/RetroPie-Setup/scriptmodules/supplementary/sdl2.sh
    sed -i '/if \[\[ "$__os_id" != "Raspbian" ]] && ! isPlatform "armv6"; then/,/fi/ d' submodule/RetroPie-Setup/scriptmodules/packages.sh

    # PATCH 4
    # fix for upstream bad package
    sed -i '/depends+=(libgles2-mesa-dev)/d' submodule/RetroPie-Setup/scriptmodules/emulators/retroarch.sh

    return 0
}


##################
# MENU FUNCTIONS #
##################

function menuManageRPS() {
    while true; do
        exec 3>&1
        selection=$(dialog \
            --backtitle "$BACKTITLE" \
            --title "Manage RetroPie-Setup" \
            --clear \
            --cancel-label "Go Back" \
            --item-help \
            --menu "Please select:" 0 0 2 \
            "1" "Re-install RetroPie-Setup" "Select for a more detailed explanation." \
            "2" "Update RetroPie-Setup" "Select for a more detailed explanation." \
            2>&1 1>&3)
        ret_val=$?
        exec 3>&-

        case $ret_val in
            $DIALOG_CANCEL)
                clear
                return
                ;;
            $DIALOG_ESC)
                clear
        return
                ;;
        esac

        case $selection in
            0)
                clear
                echo "Program terminated."
                break
                ;;
            1)
                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "Re-install RetroPie-Setup" \
                  --defaultno --no-label "Abort" --yes-label "Re-install" \
                  --yesno "\
                    \nThis will delete and then re-install RetroPie-Setup - remaining at the current version.\
                    \nIt is intended to fix mild corruption of your installation.\
                    \n\nYour emulators and configs will be preserved however.\
                    \nIf problems persist you may need to delete those too.\
                    \n\nIn that case you need to run RetroPie-Setup from the previous menu and remove it from there.\
                    " 0 0 || continue

                # Re-install (remove -> re-clone ->re-patch) RetroPie-Setup
                # a simpe re-clone inadvertantly updates RPS unless we check which commit it was at before deleting it...
                clear
                rps_version=$(git -C submodule/RetroPie-Setup log --pretty=format:'%H' -n 1)
                rm -r submodule/RetroPie-Setup
                firstTimeSetup
                su osmc -c -- "git -C submodule/RetroPie-Setup reset --hard $rps_version"
                patchRetroPie
                ;;
            2)
                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "Update RetroPie-Setup" \
                  --msgbox "\
                    \nPlease run RetroPie-Setup from the previous menu and update it from there.\
                    " 0 0
                ;;
        esac
    done
}

function menuManageThis() {
    while true; do
        exec 3>&1
        selection=$(dialog \
            --backtitle "$BACKTITLE" \
            --title "Manage $LOGO" \
            --clear \
            --cancel-label "Go Back" \
            --item-help \
            --menu "Please select:" 0 0 2 \
            "1" "Re-install $LOGO" "Select for a more detailed explanation." \
            "2" "Update $LOGO" "Select for a more detailed explanation." \
            2>&1 1>&3)
        ret_val=$?
        exec 3>&-

        case $ret_val in
            $DIALOG_CANCEL)
                clear
                return
                ;;
            $DIALOG_ESC)
                clear
        return
                ;;
        esac

        case $selection in
            0)
                clear
                echo "Program terminated."
                break
                ;;
            1)
                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "Re-install $LOGO" \
                  --defaultno --no-label "Abort" --yes-label "Re-install" \
                  --yesno "\
                    \nThis will delete and then re-install $LOGO (this installer) - remaining at the current version.\
                    \nRetroPie and RetroPie-Setup will be untouched.\
                    \n\nIt is intended to fix mild corruption of your installation.\
                    " 0 0 || continue

                # Re-install (remove -> re-clone) this installer
                # a simple re-clone inadvertantly updates it unless we check which commit it was at before refreshing it...
                installer_version=$(git log --pretty=format:'%H' -n 1)
                # move our submodule out of the way
                rm -rf /tmp/RetroPie-Setup
                mv submodule/RetroPie-Setup /tmp
                # delete and re-clone installer
                target=$(pwd)
                cd $target/..
                rm -r $target
                su osmc -c -- 'git clone https://github.com/hissingshark/retrOSMCmk2.git'
                cd $target
                # restore our submodule now or firstTimeSetup will re-clone it
                mv /tmp/RetroPie-Setup submodule/
                # revert to last version
                su osmc -c -- "git reset --hard $installer_version"
                # re-apply components
                firstTimeSetup
                ;;
            2)
                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "Update $LOGO" \
                  --defaultno --no-label "Abort" --yes-label "Update" \
                  --yesno "\
                    \nThis will update $LOGO (this installer).\
                    \nRetroPie-Setup will be cleaned, but stay at the same version.\
                    \nRetroPie itself(your emulators and their configs) will be untouched.\
                    " 0 0 || continue

                su osmc -c -- 'git reset --hard HEAD'
                su osmc -c -- 'git pull'
                firstTimeSetup
                patchRetroPie
                ;;
        esac
    done
}


#########################
# EXECUTION STARTS HERE #
#########################

# check we are running as root for all of the install work
if [ "$EUID" -ne 0 ]; then
    echo -e "\n***\nPlease run as sudo.\nThis is needed for installing any dependencies as we go and for running RetroPie-Setup.\n***"
    exit 1
fi

# Adapted from the RetroPie platform detection
case "$(sed -n '/^Hardware/s/^.*: \(.*\)/\1/p' < /proc/cpuinfo)" in
    BCM*)
        platform="rpi"
        ;;

    Vero4K|Vero4KPlus)
        platform="vero4k"
        ;;

    *)
        echo -e "*****\nUnknown platform!  $LOGO supports:\nRPi(Zero/1/2/3/4)\nVero (4K/4K+)\n*****\n"
        exit 1
        ;;
esac

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
            --menu "Please select:" 0 0 4 \
            "1" "Run RetroPie-Setup" "Runs the RetroPie-Setup script." \
            "2" "Manage RetroPie-Setup" "Re-install or update RetroPie-Setup." \
            "3" "Manage $LOGO" "Re-install, update or remove $LOGO (this installer!)." \
            "4" "Help" "Some general explanations." \
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
            0)
                clear
                echo "Program terminated."
                break
                ;;
            1)
                # Run RetroPie-Setup
                # offer to stop a running Kodi instance on RPi to save memory
                kodiRestart=0
                if [[ "$(pgrep kodi)" && "$platform" == "rpi" ]]; then
                    clear
                    dialog \
                      --backtitle "$BACKTITLE" \
                      --title "Kodi is running!" \
                      --defaultno --no-label "Leave" --yes-label "Stop" \
                      --yesno "\
                        \nOn an RPi this may be a problem.\
                        \nMemory MIGHT run out if you install anything big \"from source\".\
                        \n\nJust installing \"from binary\" will be okay.\
                        \n\nWould you like to STOP Kodi or LEAVE it running?\
                        " 0 0 && sudo systemctl stop mediacenter && kodiRestart=1
                fi

                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "Progress" \
                  --infobox "\
                  \nLaunching RetroPie-Setup...\n\
                  " 0 0

                # launch RetroPie-Setup
                submodule/RetroPie-Setup/retropie_setup.sh

                # restart Kodi if we stopped it
                if [[ "$kodiRestart" == "1" ]]; then
                    clear
                    dialog \
                      --backtitle "$BACKTITLE" \
                      --title "Kodi was stopped!" \
                      --defaultno --no-label "Leave" --yes-label "Restart" \
                      --yesno "\
                        \nWe stopped Kodi earlier.\
                        \n\nWould you like to RESTART Kodi or LEAVE it off?\
                        " 0 0 && sudo systemctl restart mediacenter
                fi
                ;;
            2)
                # manage RetroPie-Setup
                menuManageRPS
                ;;
            3)
                # manage this installer
                menuManageThis
                ;;
            4)
                # display help
                clear
                dialog \
                  --backtitle "$BACKTITLE" \
                  --title "HELP" \
                  --msgbox "\
                    \nRetroPie = Your emulators and their configuration files.  You launch it from Kodi with the addon.\
                    \n\nRetroPie-Setup = The tool for installing/updating/removing emulators in RetroPie.\
                    \n\n$LOGO = This installer, that installs the RetroPie-Setup tool and makes the whole thing work on the Vero4K\
                    \n\nPlease run RetroPie-Setup from the menu to install/update/remove your chosen emulators.\
                    \nDon't forget to enable the RetroPie launcher in your Kodi Program Addons!\
                    \n\
                    " 0 0
                ;;
        esac
    done

# the end - get back to whence we came
popd >/dev/null
