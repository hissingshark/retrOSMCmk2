#!/bin/bash


#############
# CONSTANTS #
#############

LOGO='retrOSMCmk2'
BACKTITLE="$LOGO - Installing RetroPie on your Vero4K"
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_ESC=255
FIFO=/tmp/app-switcher.fifo

###############
# GLOBAL FLAG #
###############

reinstall_sdl2=0


###################
# SETUP FUNCTIONS #
###################

# perform initial installation
function firstTimeSetup() {
  # get dependancies
  echo -e "\nFirst time setup:\n\nInstalling required dependancies..."
  depends=(dialog evtest git zip gpg)
  if [[ "$platform" == rpi* ]]; then
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

  # install scripts into RetroPie directories
  # create directories first if they don't exist - RetroPie-Setup wont remove them at install/update
  if [[ ! -d /home/osmc/RetroPie/scripts ]]; then
    mkdir -p /home/osmc/RetroPie/scripts
  fi
  # remove any old style scripts first
  rm -f /home/osmc/RetroPie/scripts/launcher.sh
  # copy over all new scripts
  cp resources/{app-switcher.sh,cec-exit.py,es-launch.sh,evdev-exit.py,evdev-helper.sh,update-check.sh} /home/osmc/RetroPie/scripts || { echo "FAILED!"; exit 1; }
  if [[ "$platform" == "vero4k" ]]; then
    cp resources/{fbset-shim.sh,tvservice-shim.sh} /home/osmc/RetroPie/scripts || { echo "FAILED!"; exit 1; }
  fi

  if [[ ! -d /opt/retropie/configs/all/ ]]; then
    mkdir -p /opt/retropie/configs/all/
  fi
  cp resources/{runcommand-onend.sh,runcommand-onstart.sh} /opt/retropie/configs/all/ || { echo "FAILED!"; exit 1; }

  # retrOSMCmk2 Kodi addon installation allowing for clean or upgrade from beta or alpha types
  cd resources
  # first configure the addon settings page for RPi/Vero4k
  cp "settings.xml.$(echo $platform | sed 's/[0-4]$//')" script.launch.retropie/resources/settings.xml || { echo "FAILED!"; exit 1; }

  if [[ ! -d /home/osmc/.kodi/addons/script.launch.retropie ]]; then # clean install of addon
    # provide retrOSMCmk2 Kodi addon as zip for install from osmc home folder
     su osmc -c -- 'zip -r /home/osmc/script.launch.retropie.zip script.launch.retropie' || { echo "FAILED!"; exit 1; }
     addon_advice="Don't forget to install the launcher addon in Kodi with \"My Addons -> Install from zip file\".\nYou'll find the zip under \"Home folder\""
  elif [[ ! -d /home/osmc/.kodi/addons/script.launch.retropie/resources ]]; then # upgrade from alpha version of addon (this scenario must mean we are updating the installer itself - not a re-install)
    # previous installer created addon structure as root - will block user attempts to install from zip
    chown -R osmc:osmc /home/osmc/.kodi/addons/script.launch.retropie
    # provide retrOSMCmk2 Kodi addon as zip for install from osmc home folder but...
    su osmc -c -- 'zip -r /home/osmc/script.launch.retropie.zip script.launch.retropie' || { echo "FAILED!"; exit 1; }
    addon_advice="Don't forget to install the new launcher addon in Kodi!\nFirst remove the old one.  Then go to \"My Addons -> Install from zip file\".\nYou'll find the zip under \"Home folder\""
  else # updating a beta version of the addon
    # sufficient to update contents of addon folder
    rm -r /home/osmc/.kodi/addons/script.launch.retropie
    cp -a script.launch.retropie /home/osmc/.kodi/addons || { echo "FAILED!"; exit 1; }
    addon_advice="The launcher addon for Kodi has been updated in place\n  - no further action required."
  fi
  cd ..
  # prepare a config destination to avoid a race condition (Kodi only creates the folder if settings have been saved - but addon may need it sooner)
  if [[ ! -d /home/osmc/.kodi/userdata/addon_data/script.launch.retropie ]]; then
    su osmc -c -- 'mkdir -p /home/osmc/.kodi/userdata/addon_data/script.launch.retropie'
  fi

  # install and enable services
  # remove any old style service unit first
  rm -f /etc/systemd/system/{emulationstation.service,app-switcher.service,cec-exit.service,evdev-exit.service,emulationstation@.service,retrosmcmk2-update.service,retrosmcmk2-update.timer}
  cp resources/{app-switcher.service,cec-exit.service,evdev-exit.service,emulationstation@.service,retrosmcmk2-update.service,retrosmcmk2-update.timer} /lib/systemd/system/ || { echo "FAILED!"; exit 1; }
  systemctl daemon-reload || { echo "FAILED!"; exit 1; }
  systemctl enable app-switcher.service || { echo "FAILED!"; exit 1; }
  systemctl enable retrosmcmk2-update.timer || { echo "FAILED!"; exit 1; }
  systemctl start retrosmcmk2-update.timer || { echo "FAILED!"; exit 1; }
  # app-switcher needs to be restarted if updated - but there may be sessions running, which will be lost
  # give user the option of closing those sessions now or rebooting the service later
  echo "dump" > $FIFO &
  sleep 0.1
  session_count=$(cat $FIFO)
  if [[ "$session_count" == "0" || $(systemctl is-active app-switcher) == "inactive" ]]; then
    systemctl stop app-switcher.service || { echo "FAILED!"; exit 1; }
    # ensure there is a config - even if blank - avoids SadFaceLoop with Buster
    sudo touch "/usr/share/alsa/alsa.conf.d/pulse.conf"
    systemctl start app-switcher.service || { echo "FAILED!"; exit 1; }
  else
    session_count=${session_count%%:*} # retrieve 1st value of a : delimited string
    plural='s'
    if [[ "$session_count" == "1" ]]; then
      plural=''
    fi
    clear
    dialog \
      --backtitle "$BACKTITLE" \
      --title "WARNING!" \
      --defaultno --no-label "Later" --yes-label "Now" \
      --yesno "\
      \nThe $LOGO fast-switching has $session_count game session$plural running in memory! \
      \nBut it needs to be restarted for updates to take affect.\
      \n\nYou can restart LATER, giving you a chance to check you've game saved properly.
      \nOr restart NOW and they'll be deleted for you.\
      \n\nNOTE - Let this be a reminder that sleeping games are not saved games!  A loss of power or a crash and they are gone.\
      " 0 0 || session_count=-1
  fi
  # sessions to be closed before restart
  if [[ "$session_count" != "-1" ]]; then
    for (( session=$session_count; session>0; session-- )); do
      clear
      dialog \
        --backtitle "$BACKTITLE" \
        --title "Progress" \
        --infobox "\
        \nClosing session: $session of $session_count\n\
        " 0 0
      echo "delete 1" > $FIFO
      sleep 1
    done
    clear
    dialog \
      --backtitle "$BACKTITLE" \
      --title "Progress" \
      --infobox "\
      \nRestarting app-switcher service now...\n\
      " 0 0
    sleep 2
    systemctl stop app-switcher.service || { echo "FAILED!"; exit 1; }
    # ensure there is a config - even if blank - avoids SadFaceLoop with Buster
    sudo touch "/usr/share/alsa/alsa.conf.d/pulse.conf"
    systemctl start app-switcher.service || { echo "FAILED!"; exit 1; }
  fi

  # perform RPi specific configuration
  if [[ "$platform" == rpi* ]]; then
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
    \n$LOGO has just installed RetroPie for you.\
    \n\nPlease run RetroPie-Setup from the next menu to start installing your chosen emulators.\
    " 0 0
  sleep 0.5
  clear
  dialog \
    --backtitle "$BACKTITLE" \
    --title "INSTALLATION COMPLETE" \
    --msgbox "\
    \n$addon_advice\
    " 0 0

  return 0
}

# re-patch Retropie after an update
function patchRetroPie() {
  # Generic Patches

  # PATCH G1
  # encapsulate the RetroPie update function with our own, so we get to repatch after they update
  # rename the original function away
  sed -i '/function updatescript_setup()/s/updatescript_setup/updatescript_setup_original/' submodule/RetroPie-Setup/scriptmodules/admin/setup.sh
  # append our wrapper function
  cat resources/updatescript_setup.sh >> submodule/RetroPie-Setup/scriptmodules/admin/setup.sh

  # PATCH G2
  # provide q3lite as RetroPie module
  wget -O submodule/RetroPie-Setup/scriptmodules/ports/q3lite.sh https://raw.githubusercontent.com/hissingshark/RetroPie-Setup/q3lite/scriptmodules/ports/q3lite.sh
  mkdir -p submodule/RetroPie-Setup/scriptmodules/ports/q3lite
  wget -O submodule/RetroPie-Setup/scriptmodules/ports/q3lite/q3lite.sh https://raw.githubusercontent.com/hissingshark/RetroPie-Setup/q3lite/scriptmodules/ports/q3lite/q3lite.sh
  wget -O submodule/RetroPie-Setup/scriptmodules/ports/q3lite/01_vero4k.diff  https://raw.githubusercontent.com/hissingshark/RetroPie-Setup/q3lite/scriptmodules/ports/q3lite/01_vero4k.diff
  chown -R osmc:osmc submodule/RetroPie-Setup/scriptmodules/ports/q3lite*

  # PATCH G3
  # remove EmulationStation from binary blacklist as we provide this on RPi3 and Vero4K
  sed -i '/if \[\[ "$__os_id" != "Raspbian" ]] && ! isPlatform "armv6"; then/,/fi/s/|ppsspp//' submodule/RetroPie-Setup/scriptmodules/packages.sh
  sed -i '/if \[\[ "$__os_id" != "Raspbian" ]] && ! isPlatform "armv6"; then/,/fi/s/emulationstation|//' submodule/RetroPie-Setup/scriptmodules/packages.sh


  # RPi2/3 and Vero4k patches
  if [[ "$platform" == rpi[2..3] || "$platform" == "vero4k" ]]; then
    # PATCH R23V1
    # RetroPie no longer host the RPi2/3 binaries because OSMC is running the unsupported GL drivers - so we provide them as well as Vero4k
    # Let RetroPie handle RPi4
    sed -i '/__binary_host="/s/.*/__binary_host="download.osmc.tv\/dev\/hissingshark"/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__has_binaries=/s/0/1/' submodule/RetroPie-Setup/scriptmodules/system.sh
    sed -i '/__binary.*_url=/s/https/http/' submodule/RetroPie-Setup/scriptmodules/system.sh
  fi

  # PATCH R23V2
  # provide our own GPG public key for signed package downloads
  sed -i '/ __gpg_signing_key/s/=.*/="retrosmcmk2@hissingshark.co.uk"/' submodule/RetroPie-Setup/scriptmodules/system.sh
  sed -i 's/--recv-keys.*/--recv-keys 5B92B8BB0BD260ECE3CE9E36688B104E245087F2/' submodule/RetroPie-Setup/scriptmodules/system.sh

  # PATCH R23V3
  # hold SDL2 version for our downloads
  sed -i '/local ver="$(get_ver_sdl2)+/s/+./+5/' submodule/RetroPie-Setup/scriptmodules/supplementary/sdl2.sh
  sed -i '/function get_ver_sdl2() {/,/}/s/".*"/"2.0.10"/' submodule/RetroPie-Setup/scriptmodules/supplementary/sdl2.sh

  # No more patches affecting RPi
  [[ "$platform" == rpi* ]] && return 0


  # All following patches must be for the Vero4K
  # PATCH V1
  # use tvservice-shim and fbset-shim instead of the real thing and handle TTY selection
  if [[ -e  "/opt/retropie/supplementary/runcommand/runcommand.sh" ]]; then
    # installed version patched in place
    # needs a fresh copy to work on, before we patch the original resource file
    cp submodule/RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh /opt/retropie/supplementary/runcommand/runcommand.sh
    sed -i '/^#!/a echo "tty" > /tmp/app-switcher.fifo\nsleep 0.1\nRC_TTY=$(cat /tmp/app-switcher.fifo)\nsudo chvt $RC_TTY' /opt/retropie/supplementary/runcommand/runcommand.sh
    sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim.sh\"\nshopt -s expand_aliases\nalias fbset=\"\/home\/osmc\/RetroPie\/scripts\/fbset-shim.sh\"/' /opt/retropie/supplementary/runcommand/runcommand.sh
  fi
  # patch the resource file regardless as there may be a re-install from there later
  sed -i '/^#!/a echo "tty" > /tmp/app-switcher.fifo\nsleep 0.1\nRC_TTY=$(cat /tmp/app-switcher.fifo)\nsudo chvt $RC_TTY' submodule/RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh
  sed -i '/TVSERVICE=/s/.*/TVSERVICE=\"\/home\/osmc\/RetroPie\/scripts\/tvservice-shim.sh\"\nshopt -s expand_aliases\nalias fbset=\"\/home\/osmc\/RetroPie\/scripts\/fbset-shim.sh\"/' submodule/RetroPie-Setup/scriptmodules/supplementary/runcommand/runcommand.sh

  # PATCH V2
  # build SDL2 from our custom fork on Vero4K due to fast switching fixes
  sed -i '/https:\/\/github.com\/RetroPie\/SDL-mirror/s/RetroPie/hissingshark/' submodule/RetroPie-Setup/scriptmodules/supplementary/sdl2.sh

  # PATCH V3
  # fix 4k/4K+ platform identification under new and old kernels
  sed -i 's/Vero4K|Vero4KPlus/*Vero*4K*/' submodule/RetroPie-Setup/scriptmodules/system.sh

  # PATCH V4
  # provide wrapper for retropie_packages.sh to chvt to current session
  mv submodule/RetroPie-Setup/retropie_packages.{sh,hidden}
  cp -a resources/retropie_packages.sh.wrapper submodule/RetroPie-Setup/retropie_packages.sh


  # END OF PATCHING
  # must update SDL2 as they may be using a stale version without the custom patches
  # but we defer it until after we've patched the RetroPie install otherwise it'll fail to download our version
  clear
  dialog \
    --backtitle "$BACKTITLE" \
    --title "SDL2 Installation" \
    --infobox "\
    \nJust (re)installing SDL2 libraries to ensure custom versions are in place...\n\
    " 0 0
  sleep 2
  sudo submodule/RetroPie-Setup/retropie_packages.sh sdl2 install_bin || { echo "FAILED!"; exit 1; }
  reinstall_sdl2=0
  clear
  dialog \
    --backtitle "$BACKTITLE" \
    --title "SDL2 Installation" \
    --infobox "\
    \nSUCCESS!\n\
    " 0 0
  sleep 2

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

        updateThis

        # restart this script to load the new version
        exec ../retrOSMCmk2/setup.sh
        ;;
    esac
  done
}

function updateThis() {
  # reset to latest upstream version instead of pulling, to handle local contamination/divergence
  su osmc -c -- 'git fetch'
  su osmc -c -- 'git reset --hard origin/master'

  # install the components with the new version on disc
  ../retrOSMCmk2/setup.sh SETUP

  # avoid patching already patched files
  su osmc -c -- "git -C submodule/RetroPie-Setup reset --hard"
  # then patch using the new version
  ../retrOSMCmk2/setup.sh PATCH
}


#########################
# EXECUTION STARTS HERE #
#########################

# check we are running as root for all of the install work
if [ "$EUID" -ne 0 ]; then
  echo -e "\n***\nPlease run as sudo.\nThis is needed for installing any dependencies as we go and for running RetroPie-Setup.\n***"
  exit 1
fi

# setup FIFO for communication
if [[ ! -p $FIFO ]]; then
  sudo -u osmc mkfifo $FIFO
fi

# Adapted from the RetroPie platform detection
case "$(sed -n '/^Hardware/s/^.*: \(.*\)/\1/p' < /proc/cpuinfo)" in
  BCM*)
    rev="0x$(sed -n '/^Revision/s/^.*: \(.*\)/\1/p' < /proc/cpuinfo)"
    cpu=$((($rev >> 12) & 15))
    case $cpu in
      1)
        platform="rpi2"
        ;;
      2)
        platform="rpi3"
        ;;
      3)
        platform="rpi4"
        ;;
    esac
    ;;
  *Vero*4K*)
    platform="vero4k"
    ;;
  *)
    echo -e "*****\nUnknown platform!  $LOGO supports:\nRPi(2/3/4)\nVero (4K/4K+)\n*****\n"
    exit 1
    ;;
esac

# all operations performed relative to this script
pushd $(dirname "${BASH_SOURCE[0]}") >/dev/null

# perform initial setup if this is the 1st run - determined by presence of RetroPie-Setup
if [[ ! -d submodule/RetroPie-Setup ]]; then
  firstTimeSetup
fi

# RetroPie-Setup will - post update - call this script specifically to re-install scripts or restore the lost patches
if [[ "$1" == "SETUP" ]]; then
  firstTimeSetup
  popd >/dev/null
  exit 0
fi

if [[ "$1" == "PATCH" ]]; then
  patchRetroPie
  popd >/dev/null
  exit 0
fi

if [[ "$1" == "UPDATE" ]]; then
  updateThis
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
      if [[ "$(pgrep kodi)" && "$platform" == rpi* ]]; then
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
