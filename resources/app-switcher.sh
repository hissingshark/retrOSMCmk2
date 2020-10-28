#!/bin/bash

# this script switches between Kodi and RetroPie, as instructed over a FIFO
# slow mode stops and starts services in turn
# fast mode halts and resumes processes via "kill STOP/CONT"
# on RPi only slow mode is available - no mode switching is performed and no Pulseaudio operations

#############
# FUNCTIONS #
#############

# platform tests - adapted from the RetroPie platform detection
function isRPi() {
  if [[ "$(sed -n '/^Hardware/s/^.*: \(.*\)/\1/p' < /proc/cpuinfo)" == BCM* ]]; then
    return 0
  else
    return 1
  fi
}


function isVero() {
  if [[ "$(sed -n '/^Hardware/s/^.*: \(.*\)/\1/p' < /proc/cpuinfo)" == *Vero*4K* ]]; then
    return 0
  else
    return 1
  fi
}


# takes an index and a reference to an array - removes that element
function cutArray() {
  local tocut=$1
  local -n array=$2
  local tmp=()

  for ((line=0; line<${#array[@]}; line++)); do
    [[ ! "$line" == "$tocut" ]] && tmp+=("${array[$line]}")
  done

  array=("${tmp[@]}")
}


# deletes a session and its data
function rmSession() {
      systemctl stop emulationstation@${TARGETS[$1]}.service
      cutArray $1 CEA
      cutArray $1 PGIDS
      cutArray $1 PLATFORMS
      cutArray $1 ROMS
      cutArray $1 TARGETS
}


# cleanup in event of a caught SIGTERM
function cleanUp() {
  fs_setting=$(cat /home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml | grep fast-switching | cut -d '>' -f2 | cut -d '<' -f1)
  [[ "$fs_setting" == "true" ]] && pulseAudio hide

  for ((slot=1; slot<${#PGIDS[@]}; slot++)); do
    rmSession 1
  done

  exit
}


# returns the index of the current CEA TV mode
function getMode() {
  echo $($TVSERVICE -s) | sed 's/.* (\(.*\)) .*/\1/'
}


# selectively sets the requested CEA TV mode on Vero only
function setMode() {
  isRPi && return

  # get vres of current mode
  mvr=$($TVSERVICE -s | sed -e 's/ //g' -e 's/^.*x//' -e 's/@.*$//')
  # get current framebuffer vres
  fvr=$(fbset | grep x | sed -e 's/^.*x//' -e 's/".*$//')

  # IF mode switching is enabled
  # AND only if the requested mode is different, else it can lose signal to TV
  # UNLESS mandatory - the framebuffer geometry reveals the new Kodi setup for 3D - a double image with a 45 pixel seperator
  if [[ "$(((mvr*2+45)))" != "$fvr" ]]; then # not MANDATORY due to 3D
    if [[ "$1" == "0" ]]; then # not enabled
      return
    elif [[ "$1" == "$(getMode)" ]]; then # mode same as the current one
      return
    fi
  fi

  if [[ "$1" == "0" ]]; then
    $TVSERVICE -e "CEA $(getMode)"
  else
    $TVSERVICE -e "CEA $1"
  fi
}


# hide PulseAudio from Kodi by swapping the config file with a blank and suspending the ALSA sink - or vice versa
# called during fast-switching and by definition on Vero only
function pulseAudio {
  if [[ "$1" == "show" ]]; then
    if [[ -f "/usr/share/alsa/alsa.conf.d/pulse.conf.disabled" ]]; then
      sudo mv /usr/share/alsa/alsa.conf.d/pulse.conf.disabled /usr/share/alsa/alsa.conf.d/pulse.conf
    fi
    sudo sed -i '/autospawn=/s/^.*$/autospawn=yes/' /etc/pulse/client.conf.d/00-disable-autospawn.conf
    sudo -u osmc pactl --server="$PA_SERVER" suspend-sink 0 0
  elif [[ "$1" == "hide" ]]; then
    sudo -u osmc pactl --server="$PA_SERVER" suspend-sink 0 1
    sudo sed -i '/autospawn=/s/^.*$/autospawn=no/' /etc/pulse/client.conf.d/00-disable-autospawn.conf
    if [[ ! -f "/usr/share/alsa/alsa.conf.d/pulse.conf.disabled" ]]; then
      sudo mv /usr/share/alsa/alsa.conf.d/pulse.conf /usr/share/alsa/alsa.conf.d/pulse.conf.disabled
      sudo touch /usr/share/alsa/alsa.conf.d/pulse.conf
    fi
  fi
}


##############
#  VARIABLES #
##############

ACTIVE_SESSION=0 # active session slot (not an index as 0 is Kodi)
# list of each session's...
CEA=(null) # CEA mode for TVService to switch mode and framebuffer geometry
PGIDS=(null) # process-group ID
PLATFORMS=(OSMC) # currently emulated platform
ROMS=(Kodi) # ROM in play
TARGETS=(null) # systemd service target
# initialised with Kodi always as the first slot - cuts down on array index arithmetic later

FIFO=/tmp/app-switcher.fifo
if isVero; then
  TVSERVICE=/home/osmc/RetroPie/scripts/tvservice-shim.sh
else
  TVSERVICE=/opt/vc/bin/tvservice
fi


#########################
# EXECUTION BEGINS HERE #
#########################

# handle SIGTERM from a shutdown/restart of the service by systemd
trap cleanUp 15

# hide pulseaudio from Kodi at boot time if fast-switching enabled (precautionary as cleanup should have taken care of this at previous shutdown/restart)
fs_setting=$(cat /home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml | grep fast-switching | cut -d '>' -f2 | cut -d '<' -f1)
[[ "$fs_setting" == "true" ]] && pulseAudio hide

# setup FIFO for communication
if [[ ! -p $FIFO ]]; then
  sudo -u osmc mkfifo $FIFO
fi

while true; do
  if read msg <$FIFO; then
    # extract supplied parameters
    opts=( $msg )
    MODE="${opts[0]}" # dumping the arrays, updating the arrays or switching application

    # socket to pulseaudioserver if running
    PA_SERVER=$(ls /home/osmc/.config/pulse/*-runtime/native)
    # TODO validate and log issues to kodi.log

    # act on requested mode
    if [[ "$MODE" == "dump" ]]; then
      # send : delimited list of...
      DUMP=$(( ${#PGIDS[@]} - 1 )) # how many slots
      for ((num=1; num<${#PGIDS[@]}; num++)); do # followed by the contents
        DUMP+=":${PLATFORMS[$num]}:${ROMS[$num]}"
      done
      echo "$DUMP" > "$FIFO"

    elif [[ "$MODE" == "tty" ]]; then
      # share session TTY for use in runcommand.sh (same as service target num)
      echo "${TARGETS[$ACTIVE_SESSION]}" > "$FIFO"

    elif [[ "$MODE" == "changelog" ]]; then
      case "${opts[1]}" in
        write)
          cutArray 0 opts
          cutArray 0 opts
          deltalog="${opts[@]}"
          ;;
        read)
          echo "$deltalog" > "$FIFO"
          ;;
        clear)
          deltalog=''
          ;;
      esac


    elif [[ "$MODE" == "update" ]]; then
      # lookup full platform name to beautify it in the menu
      case "${opts[1]}" in
        amiga)
          PLATFORMS[$ACTIVE_SESSION]="Commodore Amiga"
          ;;
        amstradcpc)
          PLATFORMS[$ACTIVE_SESSION]="Amstrad CPC"
          ;;
        arcade)
          PLATFORMS[$ACTIVE_SESSION]="Arcade Machine"
          ;;
        atari2600)
          PLATFORMS[$ACTIVE_SESSION]="Atari 2600"
          ;;
        atari5200)
          PLATFORMS[$ACTIVE_SESSION]="Atari52 00"
          ;;
        atari7800)
          PLATFORMS[$ACTIVE_SESSION]="Atari 7200"
          ;;
        atari800)
          PLATFORMS[$ACTIVE_SESSION]="Atari 800"
          ;;
        atarilynx)
          PLATFORMS[$ACTIVE_SESSION]="Atari Lynx"
          ;;
        c64)
          PLATFORMS[$ACTIVE_SESSION]="Commodore 64"
          ;;
        dreamcast)
          PLATFORMS[$ACTIVE_SESSION]="Sega Dreamcast"
          ;;
        fba)
          PLATFORMS[$ACTIVE_SESSION]="Final Burn Alpha"
          ;;
        fds)
          PLATFORMS[$ACTIVE_SESSION]="Famicom Disk System"
          ;;
        gamegear)
          PLATFORMS[$ACTIVE_SESSION]="Sega Gamegear"
          ;;
        gb)
          PLATFORMS[$ACTIVE_SESSION]="Nintendo Gameboy"
          ;;
        gba)
          PLATFORMS[$ACTIVE_SESSION]="Nintendo Gameboy Advance"
          ;;
        gbc)
          PLATFORMS[$ACTIVE_SESSION]="Nintendo Gameboy Colour"
          ;;
        genesis)
          PLATFORMS[$ACTIVE_SESSION]="Sega Genesis"
          ;;
        mame-libretro)
          PLATFORMS[$ACTIVE_SESSION]="Arcade Machine"
          ;;
        mame-mame4all)
          PLATFORMS[$ACTIVE_SESSION]="Arcade Machine"
          ;;
        mastersystem)
          PLATFORMS[$ACTIVE_SESSION]="Sega Master System"
          ;;
        megadrive)
          PLATFORMS[$ACTIVE_SESSION]="Sega Megadrive"
          ;;
        n64)
          PLATFORMS[$ACTIVE_SESSION]="Nintendo 64 (N64)"
          ;;
        nds)
          PLATFORMS[$ACTIVE_SESSION]="Nintendo DS"
          ;;
        neogeo)
          PLATFORMS[$ACTIVE_SESSION]="Neo Geo"
          ;;
        nes)
          PLATFORMS[$ACTIVE_SESSION]="Nintendo Entertainment System (NES)"
          ;;
        ngp)
          PLATFORMS[$ACTIVE_SESSION]="Neo Geo Pocket"
          ;;
        ngpc)
          PLATFORMS[$ACTIVE_SESSION]="Neo Geo Pocket Color"
          ;;
        pc)
          PLATFORMS[$ACTIVE_SESSION]="DOSBox"
          ;;
        pcengine)
          PLATFORMS[$ACTIVE_SESSION]="TurboGrafx-16 Entertainment SuperSystem"
          ;;
        ports)
          PLATFORMS[$ACTIVE_SESSION]="Port"
          ;;
        psp)
          PLATFORMS[$ACTIVE_SESSION]="Sony Playstation Portable"
          ;;
        psx)
          PLATFORMS[$ACTIVE_SESSION]="Sony Playstation (PSX)"
          ;;
        scummvm)
          PLATFORMS[$ACTIVE_SESSION]="ScummVM"
          ;;
        sega32x)
          PLATFORMS[$ACTIVE_SESSION]="Sega 32X (Project Mars)"
          ;;
        segacd)
          PLATFORMS[$ACTIVE_SESSION]="Sega CD"
          ;;
        sg-1000)
          PLATFORMS[$ACTIVE_SESSION]="Sega SG-1000"
          ;;
        snes)
          PLATFORMS[$ACTIVE_SESSION]="Super Nintendo Entertainment System (SNES)"
          ;;
        vectrex)
          PLATFORMS[$ACTIVE_SESSION]="Vectrex"
          ;;
        zxspectrum)
          PLATFORMS[$ACTIVE_SESSION]="Sinclair ZX Spectrum"
          ;;
        *)
          PLATFORMS[$ACTIVE_SESSION]="${opts[1]}"
          ;;
      esac

      # multi word ROM title forms all subsequent array elements so remove first 2 then store remaining array as string
      cutArray 0 opts
      cutArray 0 opts
      ROMS[$ACTIVE_SESSION]=$(echo "${opts[@]}" | sed 's/:/-/g') # swap : control character for -

    elif [[ "$MODE" == "delete" ]]; then
      ACTIVE_SESSION="${opts[1]}"
      rmSession $ACTIVE_SESSION

    elif [[ "$MODE" == "switch" ]]; then
      DESTINATION="${opts[1]}" # es = emulationstation, mc = mediacenter
      SPEED="${opts[2]}" # fast or slow
      REQUESTED_SESSION="${opts[3]}" # requested session to rejoin
      TV_MODE="${opts[4]}" # user selected CEA mode - otherwise some 4K TVs suffer flickering, distortion etc


      if [[ "$DESTINATION" == "es" ]]; then
        # backup the Kodi framebuffer geometry
        CEA[0]=$(getMode)

        # shutdown or halt Kodi processes
        if [[ "$SPEED" == "slow" ]]; then
          systemctl stop mediacenter
          PGIDS[0]="null"
        elif [[ "$SPEED" == "fast" ]]; then
          PGIDS[0]=$(ps xao pgid,comm | grep -m 1 "kodi.bin" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' ')
          sudo kill -STOP "-${PGIDS[0]}"
          # console normally unbound when Kodi exits - without it there's no runcommand.sh console menu
          echo 1 >/sys/class/vtconsole/vtcon1/bind
        else
          continue
        fi

        # run user script if present
        if [[ -f "/home/osmc/RetroPie/scripts/kodi-stops.sh" ]]; then
          bash "/home/osmc/RetroPie/scripts/kodi-stops.sh"
        fi

        # re-enable ALSA sink on the PA server
        [[ "$SPEED" == "fast" ]] && pulseAudio show

        # start a new session or...
        if [[ "$REQUESTED_SESSION" == 0 ]]; then
          # retroarch cores must use SDL2 for audio, else the pulseaudio setup leads to severe distortion
          [[ "$SPEED" == "fast" ]] && sed -i '/audio_driver =/c\audio_driver = sdl2' /opt/retropie/configs/all/retroarch.cfg

          # current session slot also the latest
          ACTIVE_SESSION=${#PGIDS[@]}
          # find next available target number to start the service unit
          for ((tgt=1; tgt>0; tgt++)); do
            # but ignoring 5 as TTY5 is in use - ? by OSMC update
            if [[ "$tgt" == 5 ]]; then
              continue
            elif [[ ! ${TARGETS[@]} =~ $tgt ]]; then
              TARGETS+=($tgt)
              tgt=-1
            fi
          done

          # set user selected TV mode before first use of the new TTY
          setMode $TV_MODE

          systemctl start emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
          sleep 2

          # create list of unique PGIDS
          for PGID in $(ps xao pgid,comm | grep "emulationstatio" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' '); do
            # append the newest one as the active session
            if [[ ! "${PGIDS[@]}" =~ "$PGID" ]]; then
              CEA+=(null) # to be confirmed when switching out
              PGIDS+=($PGID)
              PLATFORMS+=("EmulationStation")
              ROMS+=("N/A")
            fi
          done

        # ...or continue selected halted processes
        else
          ACTIVE_SESSION=$REQUESTED_SESSION
          # set TV mode from previous visit to session
          setMode ${CEA[$REQUESTED_SESSION]}
          # minimise any audio crackle on resuming PA
          sleep 0.5
          sudo kill -CONT "-${PGIDS[$REQUESTED_SESSION]}"
        fi

      elif [[ "$DESTINATION" == "mc" ]]; then
        if [[ "$SPEED" == "slow" ]]; then
          systemctl stop emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
          cutArray $ACTIVE_SESSION CEA
          cutArray $ACTIVE_SESSION PGIDS
          cutArray $ACTIVE_SESSION PLATFORMS
          cutArray $ACTIVE_SESSION ROMS
          cutArray $ACTIVE_SESSION TARGETS
        elif [[ "$SPEED" == "fast" ]]; then
          # store TV mode of the outgoing session
          CEA[$ACTIVE_SESSION]=$(getMode)
          # halt session
          sudo kill -STOP "-${PGIDS[$ACTIVE_SESSION]}"
          # restore the console binding for Kodi
          echo 0 >/sys/class/vtconsole/vtcon1/bind
        else
          continue
        fi

        ACTIVE_SESSION=0

        # restore the TV mode for Kodi
        setMode ${CEA[$ACTIVE_SESSION]}

        # disconnect emulators from the ALSA device to avoid blocking Kodi from it - also hides it as an option
        [[ "$SPEED" == "fast" ]] && pulseAudio hide

        # exit methods no longer required
        systemctl stop cec-exit
        systemctl stop evdev-exit

        # run user script if present
        if [[ -f "/home/osmc/RetroPie/scripts/kodi-starts.sh" ]]; then
          bash "/home/osmc/RetroPie/scripts/kodi-starts.sh"
        fi

        # start fresh Kodi session or restart the halted one
        if [[ "${PGIDS[0]}" == "null" ]]; then
          systemctl start mediacenter
        else
          sudo kill -CONT "-${PGIDS[0]}"
        fi

      else
        # bad destination requested
        continue
      fi

    else
      # bad mode requested
      continue
    fi
  fi
done
