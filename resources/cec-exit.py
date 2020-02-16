#!/usr/bin/python

import os, subprocess, sys
import xml.etree.ElementTree as ET
from subprocess import check_output

#
# FUNCTION DEFINITIONS
#

def cec_client(mode):
  global cecc_proc
  global cecc_iter

  if mode == "START":
    cecc_proc = subprocess.Popen(CLIENT, stdout=subprocess.PIPE, universal_newlines=True)
    cecc_iter = iter(cecc_proc.stdout.readline, "")
  elif mode == "STOP":
    cecc_proc.terminate()
  elif mode == "CODE":
    while True:
      line = next(cecc_iter)
      if all(["TRAFFIC" in line, ">>" in line]): # looking for key code
        # extract inbound CEC frame
        keycode = line.split(">>")[-1].strip()
        # ignore key release code that spams the output
        if keycode == "01:45":
          continue
        else:
          return keycode
  elif mode == "DESC":
    while True:
      line = next(cecc_iter)
      if "TRAFFIC" in line:
        return "No description available"
      elif all(["DEBUG" in line, "key pressed:" in line]):
        return "%s)" % (line.split("key pressed:")[-1].strip().split(")")[0])


#
# EXECUTION STARTS HERE
#


# init constant paths
CLIENT="/usr/osmc/bin/cec-client"
DATA="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/data.xml"
SETTINGS="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml"

# init process variables
cecc_proc = ""
cecc_iter = ""

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
  keycode = settings.find("keycode").text
except (IOError, AttributeError):
  # no file or corrupt
  exit()


cec_client("START")

while True:
  if cec_client("CODE") == keycode:
    break

cec_client("STOP")

if fast_switching == "false":
  os.system('echo "switch mc slow" >/tmp/app-switcher.fifo')
elif fast_switching == "true":
  os.system('echo "switch mc fast" >/tmp/app-switcher.fifo')
