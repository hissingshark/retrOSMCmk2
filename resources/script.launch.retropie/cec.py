import os, subprocess, sys, xbmc, xbmcgui
from xml.dom import minidom as MD
import xml.etree.ElementTree as ET


#
# FUNCTION DEFINITIONS
#

# programs an ESC key for RetroPie by capturing CEC events via cec-client
def capture_CEC():
  dialog.ok("Program Exit Key", "1. Press OK\n\n2. Repeatedly press the button on your TV remote that you want to exit RetroPie.")

  # disable common navigation buttons on the remote, to avoid GUI conflict during the mapping
  # load original keymap if present
  try:
    keymap_original = ET.parse("/home/osmc/.kodi/userdata/keymaps/remote.xml")
  except IOError:
    keymap_original = "ABSENT"

  # replace with a preset config to disable to buttons
  keymap_hobble = ET.parse("/home/osmc/.kodi/addons/script.launch.retropie/resources/data/hobble.xml")
  keymap_hobble.write("/home/osmc/.kodi/userdata/keymaps/remote.xml")
  xbmc.executebuiltin("Action(reloadkeymaps)")

  # start cec-client
  cecc = subprocess.Popen("/usr/osmc/bin/cec-client", stdout=subprocess.PIPE, universal_newlines=True)
  dialog.notification("CEC-client", "listening...", xbmcgui.NOTIFICATION_INFO, 1000)

  # capture stdout from the client, parsing for the inbound TRAFFIC signals
  # kodi-cec is also running so button must be pressed 3 times to avoid confusion
  # TODO may reduce this value
  keys = []
  searchmode = "code"

  for line in iter(cecc.stdout.readline, ""):
    if searchmode == "code":
      if all(["TRAFFIC" in line, ">>" in line]): # looking for key code
        # extract inbound CEC frame
        keycode = line.split(">>")[-1].strip()
        # ignore key release code that spams the output
        if keycode == "01:45":
          continue
        # add to the list of captured keys - test if pressed 3 times
        keys.append(keycode)
        if keys.count(keycode) == 3:
          # key captured - now find a human readable description
          searchmode = "desc"
    elif searchmode == "desc":
      if "TRAFFIC" in line:
        keydesc = "No description available"
        break
      elif all(["DEBUG" in line, "key pressed:" in line]):
        keydesc = "%s)" % (line.split("key pressed:")[-1].strip().split(")")[0])
        break

  # terminate cec-client otherwise, a zombie is left running, disturbing user control
  # terminate is also aggresive enough to prevent the client from shutting down normally and closing the CEC device, which breaks Kodi CEC
  cecc.terminate()

  # TODO fix needed here to restore stdout afterwards (breaks nano and likely other interactive shell programs)
  cecc.communicate() # maybe?

  # write out addon data.xml
  settings = ET.Element("settings")
  kc = ET.SubElement(settings, "keycode")
  kc.text = keycode
  kd = ET.SubElement(settings, "keydesc")
  kd.text = keydesc
  xmlstr = ET.tostring(settings).decode()
  newxml = MD.parseString(xmlstr)
  with open("/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml","w") as outfile:
      outfile.write(newxml.toprettyxml(indent="",newl=""))

  # re-enable the back button
  if keymap_original == "ABSENT":
    os.remove("/home/osmc/.kodi/userdata/keymaps/remote.xml")
  else:
    keymap_original.write("/home/osmc/.kodi/userdata/keymaps/remote.xml")
    xbmc.executebuiltin("Action(reloadkeymaps)")

  dialog.ok("New CEC Keycode", "Code = %s\nDescription = %s" % (keycode, keydesc))
  return


# display the current keycode on a popup dialog
def display_Setting():
  try:
    # read in the settings file
    settings_file = ET.parse("/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml")
    settings = settings_file.getroot()
    # parse for the keycode setting
    keycode = settings.find("keycode").text
    keydesc = settings.find("keydesc").text
  except (IOError, AttributeError):
    keycode = "No keycode set yet!"
    keydesc = "Use the \"Program exit key\" option above"

  dialog.ok("Current CEC Keycode", "Code = %s\nDescription = %s" % (keycode, keydesc))
  return


# wait for the programmed keycode and display a popup
def test_Setting():
  pass
  return


#
# EXECUTION STARTS HERE
#

# dialog handle for all popups
dialog = xbmcgui.Dialog()

# error check an arg actually passed to the script
if len(sys.argv) > 1:
  MODE = sys.argv[1]
else:
  print("ERROR!\nNo arguments supplied to %s (expected 1)" % (sys.argv[0]))
  exit()

# parse arguments for required mode
if MODE == "PROGRAM":
  capture_CEC()
elif MODE == "SETTING":
  display_Setting()
elif MODE == "TEST":
  test_Setting()
else:
  print("ERROR!\n\"%s\" is a bad argument for %s" % (MODE, sys.argv[0]))
