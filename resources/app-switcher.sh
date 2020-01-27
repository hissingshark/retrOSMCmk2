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

# takes an element number and a reference to an array - removes that element
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
# TODO we only get the first word of ROM titles containing spaces
        DUMP+=":${PLATFORMS[$num]}:"
# trying with roms in seperate quotes in case its only sending the first ekement of the array
        DUMP+="${ROMS[$num]}"
      done
      echo "$DUMP" > "$FIFO"

    elif [[ "$MODE" == "tty" ]]; then
      # share session TTY for use in runcommand.sh (same as service target num)
      echo "${TARGETS[$ACTIVE_SESSION]}" > "$FIFO"

    elif [[ "$MODE" == "update" ]]; then
      PLATFORMS[$ACTIVE_SESSION]="${opts[1]}"
#      ROMS[$ACTIVE_SESSION]="${opts[2]}"
      shift 1
      ROMS[$ACTIVE_SESSION]="${opts[@]}"

    elif [[ "$MODE" == "delete" ]]; then
      ACTIVE_SESSION="${opts[1]}"
      systemctl stop emulationstation@${TARGETS[$ACTIVE_SESSION]}.service
#      sudo kill -KILL "-${PGIDS[$ACTIVE_SESSION]}"
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
          sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
          sudo sh -c 'fbset -g 1920 1080 1920 2160 32'
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
