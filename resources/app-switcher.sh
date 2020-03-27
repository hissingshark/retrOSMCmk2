#!/bin/bash

# this script switches between Kodi and RetroPie, as instructed over a FIFO
# slow mode stops and starts services in turn
# fast mode halts and resumes processes via "kill STOP/CONT"

#############
# FUNCTIONS #
#############

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
      cutArray $1 FBSET
      cutArray $1 PGIDS
      cutArray $1 PLATFORMS
      cutArray $1 ROMS
      cutArray $1 TARGETS
}


# cleanup in event of a caught SIGTERM
function cleanUp() {
  if [[ -f "/usr/share/alsa/alsa.conf.d/pulse.conf" ]]; then
    sudo mv /usr/share/alsa/alsa.conf.d/pulse.conf /usr/share/alsa/alsa.conf.d/pulse.conf.disabled
  fi

  for ((slot=1; slot<${#PGIDS[@]}; slot++)); do
    rmSession 1
  done

  exit
}

##############
#  VARIABLES #
##############

ACTIVE_SESSION=0 # active session slot (not an index as 0 is Kodi)
# list of each session's...
FBSET=(null) # framebuffer geometry
PGIDS=(null) # process-group ID
PLATFORMS=(OSMC) # currently emulated platform
ROMS=(Kodi) # ROM in play
TARGETS=(null) # systemd service target
# initialised with Kodi always as the first slot - cuts down on array index arithmetic later

FIFO=/tmp/app-switcher.fifo



#########################
# EXECUTION BEGINS HERE #
#########################

# handle SIGTERM from a shutdown/restart of the service by systemd
trap cleanUp 15

# hide pulseaudio from Kodi at boot time  (precautionary as cleanup should have taken care of this at previous shutdown/restart)
if [[ -f "/usr/share/alsa/alsa.conf.d/pulse.conf" ]]; then
  sudo mv /usr/share/alsa/alsa.conf.d/pulse.conf /usr/share/alsa/alsa.conf.d/pulse.conf.disabled
fi

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
      4KFIX="${opts[4]}" # true or false - some 4K TVs suffer flickering, distortion etc


      if [[ "$DESTINATION" == "es" ]]; then
        # backup the Kodi framebuffer geometry
        FBSET[0]=$(fbset | grep geometry | sed 's/^.*geometry //')

        # shutdown or halt Kodi processes
        if [[ "$SPEED" == "slow" ]]; then
          systemctl stop mediacenter
          ${PGIDS[0]}="null"
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
        if [[ -f "/usr/share/alsa/alsa.conf.d/pulse.conf.disabled" ]]; then
          sudo mv /usr/share/alsa/alsa.conf.d/pulse.conf.disabled /usr/share/alsa/alsa.conf.d/pulse.conf
        fi
        sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 0

        # start a new session or...
        if [[ "$REQUESTED_SESSION" == 0 ]]; then
          # set an almost universally acceptable default framebuffer geometry
          # TODO make this user selectable in addon settings for odd TV and monitor cases as "4K Fix" - they also need the mode setting though
          if [[ "$4KFIX" == "true" ]]; then
            echo '1080p50hz' > /sys/class/display/mode
            fbset -g 1920 1080 1920 2160 32
          else
            fbset -g 1920 1080 1920 2160 32
          fi

          # retroarch cores must use SDL2 for audio, else the pulseaudio setup leads to severe distortion
          sed -i '/audio_driver =/c\audio_driver = sdl2' /opt/retropie/configs/all/retroarch.cfg

          # current session slot also the latest
          ACTIVE_SESSION=${#PGIDS[@]}
          # find next available target number to start the service unit
          for ((tgt=1; tgt>0; tgt++)); do
            if [[ ! ${TARGETS[@]} =~ $tgt ]]; then
              TARGETS+=($tgt)
              tgt=-1
            fi
          done
          systemctl start emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
          sleep 2

          # create list of unique PGIDS
          for PGID in $(ps xao pgid,comm | grep "emulationstatio" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' '); do
            # append the newest one as the active session
            if [[ ! "${PGIDS[@]}" =~ "$PGID" ]]; then
              FBSET+=(null) # to be confirmed when switching out
              PGIDS+=($PGID)
              PLATFORMS+=("EmulationStation")
              ROMS+=("N/A")
            fi
          done

        # ...or continue selected halted processes
        else
          ACTIVE_SESSION=$REQUESTED_SESSION
          # set framebuffer geometry from previous visit to session
          fbset -g ${FBSET[$REQUESTED_SESSION]}
          # minimise any audio crackle on resuming PA
          sleep 0.5
          sudo kill -CONT "-${PGIDS[$REQUESTED_SESSION]}"
        fi

      elif [[ "$DESTINATION" == "mc" ]]; then
        if [[ "$SPEED" == "slow" ]]; then
          systemctl stop emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
          cutArray $ACTIVE_SESSION FBSET
          cutArray $ACTIVE_SESSION PGIDS
          cutArray $ACTIVE_SESSION PLATFORMS
          cutArray $ACTIVE_SESSION ROMS
          cutArray $ACTIVE_SESSION TARGETS
        elif [[ "$SPEED" == "fast" ]]; then
          # store framebuffer geometry of the outgoing session
          FBSET[$ACTIVE_SESSION]=$(fbset | grep geometry | sed 's/^.*geometry //')
          # halt session
          sudo kill -STOP "-${PGIDS[$ACTIVE_SESSION]}"
          # restore the console binding for Kodi
          echo 0 >/sys/class/vtconsole/vtcon1/bind
        else
          continue
        fi
        ACTIVE_SESSION=0
        # restore the framebuffer geometry for Kodi
        fbset -g ${FBSET[$ACTIVE_SESSION]}

        # disconnects emulators from the ALSA device to avoid blocking Kodi from it - also hides it as an option
        sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 1
        if [[ -f "/usr/share/alsa/alsa.conf.d/pulse.conf" ]]; then
          sudo mv /usr/share/alsa/alsa.conf.d/pulse.conf /usr/share/alsa/alsa.conf.d/pulse.conf.disabled
        fi

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
