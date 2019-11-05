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
    MODE="${opts[1]}" # fast, slow or pre(load)

    # group process IDs if applications pre-loaded
    ES_GPID=$(ps xao pgid,comm | grep -m 1 "emulationstatio" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' ')
    MC_GPID=$(ps xao pgid,comm | grep -m 1 "kodi.bin" | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f1 | tr -d ' ')

    if [[ "$DESTINATION" == "es" ]]; then
      sudo chvt 1
      sudo sh -c 'echo 1080p50hz > /sys/class/display/mode'
      sudo sh -c 'fbset -g 1920 1080 1920 2160 32'

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

      systemctl stop cec-exit

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

