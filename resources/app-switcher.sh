#!/bin/bash

# this script switches between Kodi and RetroPie, as instructed over a FIFO
# slow mode stops and starts services in turn
# fast mode halts and resumes processes via "kill STOP/CONT"

#LOG=/home/osmc/debug.log
#echo  "Log Starts.." > $LOG
#echo  "" >> $LOG

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



##############
#  VARIABLES #
##############

ACTIVE_SESSION=0 # active session slot (not an index as 0 is Kodi)
# list of each session's...
PGIDS=(null) # process-group ID
PLATFORMS=(OSMC) # currently emulated platform
ROMS=(Kodi) # ROM in play
TARGETS=(null) # systemd service target
# initialised with Kodi always as the first slot - cuts down on variable arithmetic later

FIFO=/tmp/app-switcher.fifo



#########################
# EXECUTION BEGINS HERE #
#########################

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
      systemctl stop emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
      cutArray $ACTIVE_SESSION PGIDS
      cutArray $ACTIVE_SESSION PLATFORMS
      cutArray $ACTIVE_SESSION ROMS
      cutArray $ACTIVE_SESSION TARGETS

    elif [[ "$MODE" == "switch" ]]; then
      DESTINATION="${opts[1]}" # es = emulationstation, mc = mediacenter
      SPEED="${opts[2]}" # fast or slow
      REQUESTED_SESSION="${opts[3]}" # requested session to rejoin
      4KFIX="${opts[4]}" # true or false - some 4K TVs suffer flickering, distortion etc


      if [[ "$DESTINATION" == "es" ]]; then
        if [[ "$4KFIX" == "true" ]]; then
          echo '1080p50hz' > /sys/class/display/mode
          fbset -g 1920 1080 1920 2160 32
        fi

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
        sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 0

        # start a new session or...
        if [[ "$REQUESTED_SESSION" == 0 ]]; then
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

          # create list of unique PGIDS (in practice just appends the newest one as the active session)
          for PGID in $(ps xao pgid,comm | grep "emulationstatio" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' '); do
            if [[ ! "${PGIDS[@]}" =~ "$PGID" ]]; then
              PGIDS+=($PGID)
              PLATFORMS+=("EmulationStation")
              ROMS+=("N/A")
            fi
          done

        # ...or continue selected halted processes
        else
          ACTIVE_SESSION=$REQUESTED_SESSION
          # minimise any audio crackle on resuming PA
          sleep 0.5
          sudo kill -CONT "-${PGIDS[$REQUESTED_SESSION]}"
        fi

      elif [[ "$DESTINATION" == "mc" ]]; then
        if [[ "$SPEED" == "slow" ]]; then
          systemctl stop emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
          cutArray $ACTIVE_SESSION PGIDS
          cutArray $ACTIVE_SESSION PLATFORMS
          cutArray $ACTIVE_SESSION ROMS
          cutArray $ACTIVE_SESSION TARGETS
        elif [[ "$SPEED" == "fast" ]]; then
          sudo kill -STOP "-${PGIDS[$ACTIVE_SESSION]}"
          # restore the console binding for Kodi
          echo 0 >/sys/class/vtconsole/vtcon1/bind
        else
          continue
        fi
        ACTIVE_SESSION=0

        # disconnects emulators from the audio device to avoid blocking Kodi from it
        sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 1

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
