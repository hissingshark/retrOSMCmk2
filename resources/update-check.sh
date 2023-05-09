#!/bin/bash
# scheduled daily check of the retrOSMCmk2 repository for updates

FIFO='/tmp/app-switcher.fifo'

mode=$1

# get lastest commit list from upstream repository
cd /home/osmc/retrOSMCmk2
git fetch

# check if the local copy is behind upstream
behind=$(git status | grep Your | grep behind | sed 's/^.*by //' | sed 's/ .*//')

if [[ "$behind" == "" ]]; then
  # nothing to do
  echo ""
elif [[ "$mode" != "manual" ]]; then
    # notify Kodi user of available updates via an addon popup
    kodi-send --action='RunScript("script.launch.retropie", UPDATE, NOTIFY)'
else
  # compose changelog message
  # extract the outstanding commit history
  readarray log <<< $(git log --oneline -$behind origin/master)

  # compile tag seperated list of commit messages without the SHA numbers
  for (( entry=1; entry<="${#log[@]}"; entry++ )); do
    formatted="$(echo "${log[$entry-1]}" | cut -d ' ' -f2-)"
    # markup urgent entries in red
    if [[ "$formatted" == *"URGENT"* ]]; then
      formatted="[COLOR red]$formatted[/COLOR]"
    fi
    formatted="<ENTRY>$formatted"
    changelog+=$formatted
  done

  # return changelog via stdout
  echo "$changelog"
fi
