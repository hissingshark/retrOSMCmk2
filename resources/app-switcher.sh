#!/bin/bash

# switches between Kodi and RetroPie, as instructed over a FIFO
# slow mode stops and starts services in turn
# fast mode halt and resumes processes via "kill STOP/CONT"

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

      if [[ "$MODE" == "slow" ]]; then
        systemctl stop mediacenter
      elif [[ "$MODE" == "fast" ]]; then
        sudo kill -STOP "-$MC_GPID"
        # console normally unbound when Kodi exits - without it there's no runcommand.sh console menu
        echo 1 >/sys/class/vtconsole/vtcon1/bind
      else
        continue
      fi

      if [[ -z "$ES_GPID" ]]; then
        # retroarch cores must use SDL2 for audio, else the pulseaudio setup leads to severe distortion
        sed -i '/audio_driver =/c\audio_driver = sdl2' /opt/retropie/configs/all/retroarch.cfg
        systemctl start emulationstation
      else
        sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 0
        # minimise any audio crackle on resuming PA
        sleep 0.5
        sudo kill -CONT "-$ES_GPID"
      fi

    elif [[ "$DESTINATION" == "mc" ]]; then
      if [[ "$MODE" == "slow" ]]; then
        systemctl stop emulationstation
      elif [[ "$MODE" == "fast" ]]; then
        sudo kill -STOP "-$ES_GPID"
        # restore the console binding for Kodi
        echo 0 >/sys/class/vtconsole/vtcon1/bind
      else
        continue
      fi

      # disconnects emulators from the audio device to avoid blocking Kodi from it
      sudo -u osmc pactl --server="$PA_SERVER" suspend-sink alsa_output.platform-aml_m8_snd.46.analog-stereo 1

      # exit methods no longer required
      systemctl stop cec-exit
      systemctl stop evdev-exit

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

