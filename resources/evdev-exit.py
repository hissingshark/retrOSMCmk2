#!/usr/bin/python

import os, pwd, subprocess, sys
from os import path
import xml.etree.ElementTree as ET
from subprocess import check_output


#
# FUNCTION DEFINITIONS
#

# monitors FIFO for the exit signal
def monitorFIFO():
  global FIFO_PATH

  while True:
    with open(FIFO_PATH) as fifo:
      for line in fifo:
        line = line.rstrip()
        if line == "EXIT":
          return line



#
# EXECUTION STARTS HERE
#

# init constant paths
EVHELPER="/home/osmc/RetroPie/scripts/evdev-helper.sh"
DATA="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/data.xml"
SETTINGS="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml"
FIFO_PATH="/tmp/evdev-exit.fifo"

# load addon settings
try:
  settings_file = ET.parse(SETTINGS)
  settings = settings_file.getroot()
  for setting in settings:
    if setting.get("id") == "fast-switching":
      fast_switching = setting.text
except (IOError, AttributeError): # no file or corrupt so fall back to slow
  fast_switching = "false"

# load data file/tree
try: # read in the settings file
  settings_file = ET.parse(DATA)
  settings = settings_file.getroot()
  gamepad = settings.find("gamepad").text
  hotbtncode = settings.find("hotbtncode").text
  exitbtncode = settings.find("exitbtncode").text
except (IOError, AttributeError):
  # no file or corrupt
  exit()

# ensure FIFO is in place for evdev-helper comms
if not path.exists(FIFO_PATH):
  os.mkfifo(FIFO_PATH)
  uid=(pwd.getpwnam('osmc').pw_uid)
  gid=(pwd.getpwnam('osmc').pw_gid)
  os.chown(FIFO_PATH, uid, gid)

subprocess.Popen([EVHELPER, "CATCHCOMBO", "LIVE", gamepad, hotbtncode, exitbtncode])
msg = monitorFIFO()

if msg != "EXIT":
  # big error has occured! EXIT is the only possible signal
  exit()
else:
  if fast_switching == "false":
    os.system('echo "switch mc slow" >/tmp/app-switcher.fifo')
  elif fast_switching == "true":
    os.system('echo "switch mc fast" >/tmp/app-switcher.fifo')
