#!/bin/bash
# scheduled daily check of the retrOSMCmk2 repository for updates

FIFO='/tmp/app-switcher.fifo'

mode=$1

# get lastest commit list from upstream repository
cd /home/osmc/retrOSMCmk2
git fetch

# check if the local copy is behind upstream
behind=$(git status | grep Your | grep behind | sed 's/^.*by //' | sed 's/ .*//')

if [[ "$behind" != "" ]]; then
  # start to compose FIFO message
  msg="changelog write "

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

  msg+="$changelog"

  # send changelog to the app-switcher
  echo "$msg" > /tmp/app-switcher.fifo

  # notify Kodi user via addon popup
  [[ "$mode" == "manual" ]] || kodi-send --action='RunScript("script.launch.retropie", UPDATE, NOTIFY)'
else
  # clear any stale changelog from the app-switcher
  echo "changelog clear" > /tmp/app-switcher.fifo
  # exit silently (addon handles manual checks with no available updates)
fi
