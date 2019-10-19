import os, signal, subprocess, sys, time, xbmc, xbmcgui
import xml.etree.ElementTree as ET
from xml.dom import minidom as MD
from shutil import copyfile
from subprocess import check_output



#
# FUNCTION DEFINITIONS
#

def cec_client(mode):
  global cecc_proc
  global cecc_iter

  if mode == "START":
    dialog.notification("CEC-client", "listening...", xbmcgui.NOTIFICATION_INFO, 1000)
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

# blocks Kodi response to main remote navigation buttons
def remote_jammer(toggle):
  if toggle == "START": # disable common navigation buttons on the remote, to avoid GUI conflict during the mapping
    # hide an existing user keymap
    if os.path.exists(REMOTE):
      copyfile(REMOTE, HIDDEN)
    # replace with a preset NOOP config to disable to buttons
    copyfile(HOBBLE, REMOTE)
    xbmc.executebuiltin("Action(reloadkeymaps)")

  elif toggle == "STOP": # re-enable the back button
    if os.path.exists(HIDDEN):
      copyfile(HIDDEN, REMOTE)
      os.remove(HIDDEN)
    else:
      os.remove(REMOTE)

    xbmc.executebuiltin("Action(reloadkeymaps)")
  return



#
# EXECUTION STARTS HERE
#

# error check an arg was actually passed to the script
if len(sys.argv) > 1:
  MODE = sys.argv[1]
else:
  xbmc.log("retrOSMCmk2 Launcher: ERROR!\nNo arguments supplied to %s (expected 1)" % (sys.argv[0]), level=xbmc.LOGNOTICE)
  exit()

# init constant paths
CLIENT="/usr/osmc/bin/cec-client"
DATA="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/data.xml"
HOBBLE="/home/osmc/.kodi/addons/script.launch.retropie/resources/data/hobble.xml"
REMOTE="/home/osmc/.kodi/userdata/keymaps/remote.xml"
HIDDEN="/home/osmc/.kodi/userdata/keymaps/remote.xml.hidden"

# init dialog handle for all popups
dialog = xbmcgui.Dialog()
cecc_proc = ""
cecc_iter = ""

# init settings file/tree
try: # read in the settings file
  settings_file = ET.parse(DATA)
  settings = settings_file.getroot()
  keycode = settings.find("keycode").text
  keydesc = settings.find("keydesc").text
except (IOError, AttributeError): # no file or corrupt
  xbmc.log("retrOSMCmk2 Launcher: \"/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/data.xml\" missing or corrupt on this run", level=xbmc.LOGNOTICE)
  # create temporary default tree
  keycode = "No keycode set yet!"
  keydesc = "Use the \"Program exit key\" option above."
  settings = ET.Element("settings")
  ET.SubElement(settings, "keycode").text = keycode
  ET.SubElement(settings, "keydesc").text = keydesc


# parse arguments for required mode
if MODE == "PROGRAM":
  dialog.ok("Program Exit Key", "1. Press OK\n\n2. Repeatedly press the button on your TV remote that you want to exit RetroPie.")
  remote_jammer("START")
  cec_client("START")

  # collect 2 presses of the same key and the description that follows if it exists
  keys = [keycode]
  while not keys.count(keys[-1]) == 2:
    keys.append(cec_client("CODE"))

  keycode = keys[-1]
  keydesc = cec_client("DESC")

  # write out addon data.xml
  settings.find("keycode").text = keycode
  settings.find("keydesc").text = keydesc
  xmlstr = ET.tostring(settings).decode()
  newxml = MD.parseString(xmlstr)
  with open(DATA,"w") as outfile:
      outfile.write(newxml.toprettyxml(indent="",newl=""))

  cec_client("STOP")
  remote_jammer("STOP")
  dialog.ok("CEC-client", "Keycode = %s\nDescription = %s" % (keycode, keydesc))


elif MODE == "SETTING":
  dialog.ok("Current CEC Keycode", "Code = %s\nDescription = %s" % (keycode, keydesc))


elif MODE == "TEST":
  if keycode == "No keycode set yet!":
    dialog.ok("Test Exit Key", "Code = %s\nDescription = %s" % (keycode, keydesc))
  else:
    dialog.ok("Test Exit Key", "1. Press OK\n\n2. Repeatedly press the button on your TV remote that you have set to exit RetroPie.")
    remote_jammer("START")
    cec_client("START")

  attempts = 3
  for press in range(0, attempts):
    if cec_client("CODE") == keycode:
      msg = "Correct keycode detected!"
      break
    elif press < (attempts - 1):
      continue
    else:
      msg = "The programmed keycode was not detected..."

  cec_client("STOP")
  remote_jammer("STOP")
  dialog.ok("CEC-client", msg)


elif MODE == "BLOCK":
  pass # TODO 


elif MODE == "WATCHDOG":
  cec_client("START")

  while True:
    if cec_client("CODE") == keycode:
      break

  cec_client("STOP")
  time.sleep(1)
  pid = int(check_output(["pidof","-s","emulationstation"]))
  gpid = os.getpgid(pid)
  os.kill(-gpid, signal.SIGKILL)


else:
  xbmc.log("ERROR!\n\"%s\" is a bad argument for %s" % (MODE, sys.argv[0]), level=xbmc.LOGNOTICE)
