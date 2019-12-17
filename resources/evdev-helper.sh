#!/bin/bash


#########
# SETUP #
#########

# for spawning thread processes
SELF=$0

# the mode of operation - obviously I didn't need to tell you that
MODE=$1

# named pipe for communicating with addon.py
FIFO="/tmp/evdev-exit.fifo"

# we look for gamepads here
DEV_PATH="/dev/input/by-id/"
#DEV_PATH="/dev/input/"


#############
# FUNCTIONS #
#############

function killThreads() {
# kills self and all other helper threads
  MSG=$1
  echo $MSG > $FIFO &
  killall ${SELF##*/} evtest
  # that includes this instance - so end of execution
}


#########################
# EXECUTION STARTS HERE #
#########################

if [[ "$MODE" == "KILL" ]]; then
  # acts a watchdog timer and provides an explanation to addon.py when it kills itself and all other helper threads - so cold
  DELAY=$2
  MSG=$3
  sleep $DELAY
  killThreads $MSG


elif [[ "$MODE" == "SCANMULTI" ]]; then
  # find all connected gamepads and report the name of the first to press a button (and the button code itself)
  pads=0
  for gamepad in $(ls $DEV_PATH | grep "event-joystick"); do
    ((pads++))
    # spawn a thread for each gamepad to capture a button press
    $SELF "SCANSINGLE" $gamepad &
  done

  if [[ "$pads" -eq "0" ]]; then
    killThreads "NOPADS"
  else
    # start the watchdog clock in case something goes wrong or just no buttons are pressed
    $SELF "KILL" 10 "TIMEOUT" &
  fi
  exit


elif [[ "$MODE" == "SCANSINGLE" ]]; then
  # report the next button press from a specific controller
  GAMEPAD=$2
  SUBMODE=$3

  if [[ "$SUBMODE" == "PARENT" ]]; then
    # start the watchdog clock in case something goes wrong or just no buttons are pressed
    $SELF "KILL" 10 "TIMEOUT" &
  fi

  # grab button events
  evtest --grab "/dev/input/by-id/$GAMEPAD" | while read line; do
    btncode=$(echo $line | grep EV_KEY | cut -d ")" -f2 | cut -d "(" -f2 )
    if [[ $btncode == BTN_* ]]; then
      # got a BTN_ code, but it must be a release event, to avoid resending a long press multiple times in error
      if [[ "${line: -1}" == "0" ]]; then
        killThreads "$GAMEPAD:$btncode"
      fi
    fi
  done


elif [[ "$MODE" == "CATCHCOMBO" ]]; then
  # report when the hotkey and exit button combo has been pressed on a specific controller
  SUBMODE=$2
  GAMEPAD=$3
  HOTKEY=$4
  EXITKEY=$5

  if [[ "$SUBMODE" == "TEST" ]]; then
    # in Kodi we want to prevent the controller driving the menus during programming.
    grab="--grab"
    # start the watchdog clock in case something goes wrong or just no buttons are pressed
    $SELF "KILL" 10 "TIMEOUT" &
  elif [[ "$SUBMODE" == "LIVE" ]]; then
    # in Retropie controls must pass to the emulator uninterrupted
    grab=""
  else
    echo "Bad SUBMODE: $SUBMODE" >> /home/osmc/evdev-helper.log
  fi

  toggle=0
  evtest $grab "/dev/input/by-id/$GAMEPAD" | while read line; do
    btncode=$(echo $line | grep EV_KEY | cut -d ")" -f2 | cut -d "(" -f2 )
    if [[ "$btncode" == "$HOTKEY" ]]; then
      # get pressed/released status of hotkey
      toggle=${line: -1}
    elif [[ "$btncode" == "$EXITKEY" ]]; then
      if [[ "${line: -1}" == "1" ]]; then
        # exit button pressed, so if hotkey was already held down it is time to exit
        if [[ "$toggle" == "1" ]]; then
          killThreads "EXIT"
        fi
      fi
    fi
  done


else
  echo "Bad MODE: $MODE" >> /home/osmc/evdev.log
fi
