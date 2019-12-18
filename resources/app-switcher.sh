#!/bin/bash


FIFO=/tmp/app-switcher.fifo

if [[ ! -p $FIFO ]]; then
  sudo -u osmc mkfifo $FIFO
fi


while true; do
  if read msg <$FIFO; then
    # supplied parameters
    opts=( $msg )
    DESTINATION="${opts[0]}" # es = emulationstation, mc = mediacenter
    MODE="${opts[1]}" # fast or slow
    4KFIX="${opts[2]}" # true or false - some 4K TVs suffer flickering, distortion etc

    # group process IDs if applications are pre-loaded
    ES_GPID=$(ps xao pgid,comm | grep -m 1 "emulationstatio" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' ')
    MC_GPID=$(ps xao pgid,comm | grep -m 1 "kodi.bin" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' ')

    if [[ "$DESTINATION" == "es" ]]; then
      if [[ "$4KFIX" == "true" ]]; then
        sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
        sudo sh -c 'fbset -g 1920 1080 1920 2160 32'
      fi

# Still needed? Wasn't part of the manual tests...
      sudo chvt 1

      if [[ "$MODE" == "slow" ]]; then
        systemctl stop mediacenter
      elif [[ "$MODE" == "fast" ]]; then
        sudo kill -STOP "-$MC_GPID"
      elif [[ "$MODE" == "preload" ]]; then
        systemctl start emulationstation
        sleep 5
        ES_GPID=$(ps xao pgid,comm | grep -m 1 "emulationstatio" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' ')
        sudo kill -STOP "-$ES_GPID"
      else
        continue
      fi

      if [[ -z "$ES_GPID" ]]; then
        systemctl start emulationstation
      else
        sudo kill -CONT "-$ES_GPID"
      fi

    elif [[ "$DESTINATION" == "mc" ]]; then
      if [[ "$MODE" == "slow" ]]; then
        systemctl stop emulationstation
      elif [[ "$MODE" == "fast" ]]; then
        sudo kill -STOP "-$ES_GPID"
      else
        continue
      fi

      sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 1

      systemctl stop cec-exit
      systemctl stop evdev-exit

      sleep 1 # might avoid screen swap glitch when Kodi returns
      
      if [[ -z "$MC_GPID" ]]; then
        systemctl start mediacenter
      else
        sudo kill -CONT "-$MC_GPID"
      fi

    else
      continue
    fi
  fi
done

