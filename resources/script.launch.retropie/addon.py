#!/usr/bin/python

import os, pyxbmct, signal, subprocess, sys, time, xbmc, xbmcgui
from os import path
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


# reads a single line from a FIFO
def read_FIFO(path):
  global SUBMODE

  while True:
    with open(path) as fifo:
      for line in fifo:
        line = line.rstrip()
        if line == "NOPADS":
          dialog.ok("Program Exit Buttons", "No gamepads detected!")
          exit()
        elif line == "TIMEOUT":
          if SUBMODE == "PROGRAM":
            dialog.ok("Program Exit Buttons", "No button pressed!")
          else:
            dialog.ok("Test Exit Buttons", "Did not detect exit combination!")
          exit()
        elif ':' in line:
          return line
        elif line == "0":
          return line
        elif line == "EXIT":
          return line


#
# class for GUI
#

class slotManager(pyxbmct.AddonDialogWindow):

  def __init__(self, title=''):
    super(slotManager, self).__init__(title)
    self.setGeometry(1280, 720, 9, 10)

    self.slot_btn = []
    self.del_btn = []
    self.select_action = []
    self.delete_action = []
    self.new_slot_action = self.selectAction(self, 0)
    self.settings_action = self.settingsAction(self)

    self.draw_slot_menu()
    self.map_menu_nav()
    self.connect(pyxbmct.ACTION_NAV_BACK, self.close)

  def draw_slot_menu(self):
    global go_button

    # draw and configure select and delete buttons for each slot
    row = 0
    while row < slots:
      platform = labels.pop(0)
      rom = labels.pop(0)

      self.slot_btn.append(pyxbmct.Button('  %s\n  %s' % (platform, rom), alignment=pyxbmct.ALIGN_LEFT))
      self.placeControl(self.slot_btn[row], row, 0, 1, 9)
      self.select_action.append(self.selectAction(self, row+1))
      self.connect(self.slot_btn[row], self.select_action[row].setTargetSlot)

      self.del_btn.append(pyxbmct.Button('Delete', alignment=pyxbmct.ALIGN_CENTER))
      self.placeControl(self.del_btn[row], row, 9)
      self.delete_action.append(self.deleteAction(self, row+1))
      self.connect(self.del_btn[row], self.delete_action[row].deleteSlot)

      row += 1

    # draw "new session" button if free space (sits in the centre, spread over 2 cells)
    if slots < MAX_SLOTS:
      new_row = (((MAX_SLOTS - slots) / 2) + slots)
      self.new_btn = pyxbmct.Button(go_button, alignment=pyxbmct.ALIGN_CENTER)
      self.placeControl(self.new_btn, new_row, 4, 1, 2)
      self.connect(self.new_btn, self.new_slot_action.setTargetSlot)
    # and a settings button in the bottom left corner, only unavailalbe if 9 slots are used - unlikely
      self.settings_btn = pyxbmct.Button('Settings', alignment=pyxbmct.ALIGN_CENTER)
      self.placeControl(self.settings_btn, 8, 0, 1, 1)
      self.connect(self.settings_btn, self.settings_action.openSettings)

  def map_menu_nav(self):
    # slot left/right navigation between select and delete columns
    row = 0
    while row < slots:
      self.slot_btn[row].controlLeft(self.del_btn[row])
      self.slot_btn[row].controlRight(self.del_btn[row])
      self.del_btn[row].controlLeft(self.slot_btn[row])
      self.del_btn[row].controlRight(self.slot_btn[row])
      row += 1

    # up/down navigation for select and delete rows
    if slots > 1:
      # upwards
      row = 1
      while row < slots:
        self.slot_btn[row].controlUp(self.slot_btn[row-1])
        self.del_btn[row].controlUp(self.del_btn[row-1])
        row += 1
      # downwards
      row = 0
      while row < (slots - 1):
        self.slot_btn[row].controlDown(self.slot_btn[row+1])
        self.del_btn[row].controlDown(self.del_btn[row+1])
        row += 1

    # the "Start New Session" button actually exists and has somewhere to go
    if slots > 0 and slots < MAX_SLOTS:
      self.new_btn.controlUp(self.slot_btn[slots-1])
      self.new_btn.controlDown(self.slot_btn[0])
      self.slot_btn[0].controlUp(self.new_btn)
      self.slot_btn[slots-1].controlDown(self.new_btn)
      self.del_btn[0].controlUp(self.new_btn)
      self.del_btn[slots-1].controlDown(self.new_btn)
    elif slots == MAX_SLOTS:
      self.slot_btn[0].controlUp(self.slot_btn[slots-1])
      self.slot_btn[slots-1].controlDown(self.slot_btn[0])
      self.del_btn[0].controlUp(self.del_btn[slots-1])
      self.del_btn[slots-1].controlDown(self.del_btn[0])

    # "Settings" button exists (because "Start New Session" does)
    if slots < MAX_SLOTS:
      self.new_btn.controlLeft(self.settings_btn)
      self.settings_btn.setNavigation(self.new_btn,self.new_btn,self.new_btn,self.new_btn)


    # Set initial focus
    if slots > 0:
      self.setFocus(self.slot_btn[0])
    else:
      self.setFocus(self.new_btn)

  # subclasses for GUI button actions
  class selectAction():
    def __init__(self, parent, slot):
      self.parent = parent
      self.slot = slot

    def setTargetSlot(self):
      global fast_switching
      global target_slot
      if (fast_switching == "false" and self.slot > 0):
        # disable launch of slots in "slow mode"
        dialog.ok("App-Switching", "Please re-enable \"fast switching\" to access paused slots.")
      else:
        target_slot = self.slot
        self.parent.close()

  class deleteAction():
    def __init__(self, parent, slot):
      self.parent = parent
      self.slot = slot

    def deleteSlot(self):
      global SWITCHER_FIFO
      os.system('echo "delete %d" > %s' % (self.slot, SWITCHER_FIFO))

      global slots_master
      slots_master -= 1

      global labels_master
      labels_master.pop(self.slot * 2 - 2)
      labels_master.pop(self.slot * 2 - 2)

      global target_slot
      target_slot = -2
      self.parent.close()

  class settingsAction():
    def __init__(self, parent):
      self.parent = parent

    def openSettings(self):
      self.parent.close()
      xbmc.executebuiltin("Addon.openSettings(script.launch.retropie)")
      exit()

#
# EXECUTION STARTS HERE
#

# init constant paths
CLIENT="/usr/osmc/bin/cec-client"
EVHELPER="/home/osmc/RetroPie/scripts/evdev-helper.sh"
TVSERVICE="/home/osmc/RetroPie/scripts/tvservice-shim.sh"
DATA="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/data.xml"
HIDDEN="/home/osmc/.kodi/userdata/keymaps/remote.xml.hidden"
HOBBLE="/home/osmc/.kodi/addons/script.launch.retropie/resources/data/hobble.xml"
REMOTE="/home/osmc/.kodi/userdata/keymaps/remote.xml"
SETTINGS="/home/osmc/.kodi/userdata/addon_data/script.launch.retropie/settings.xml"
EVDEV_FIFO="/tmp/evdev-exit.fifo"
SWITCHER_FIFO="/tmp/app-switcher.fifo"
MAX_SLOTS=9

# init dialog handle for all settings related popups
dialog = xbmcgui.Dialog()
cecc_proc = ""
cecc_iter = ""


# load data file/tree
try: # read in the data file
  data_file = ET.parse(DATA)
  data = data_file.getroot()
except (IOError, AttributeError): # no file or corrupt
  xbmc.log("retrOSMCmk2 Launcher: \"%s\" missing or corrupt on this run" % (DATA), level=xbmc.LOGNOTICE)
  # create temporary default tree
  data = ET.Element("data")

# parse the elements, defaulting and repairing if missing
try:
  keycode = data.find("keycode").text
except (AttributeError): # missing element
  keycode = "No keycode set yet!"
  ET.SubElement(data, "keycode").text = keycode
try:
  keydesc = data.find("keydesc").text
except (AttributeError):
  keydesc = "Use the \"Program exit key\" option above."
  ET.SubElement(data, "keydesc").text = keydesc
try:
  gamepad = data.find("gamepad").text
except (AttributeError):
  gamepad = "Setup still required:"
  ET.SubElement(data, "gamepad").text = gamepad
try:
  hotbtncode = data.find("hotbtncode").text
except (AttributeError):
  hotbtncode = "No button code set yet!"
  ET.SubElement(data, "hotbtncode").text = hotbtncode
try:
  exitbtncode = data.find("exitbtncode").text
except (AttributeError):
  exitbtncode = "Use the \"Program exit key\" option above."
  ET.SubElement(data, "exitbtncode").text = exitbtncode
try:
  resolution = data.find("resolution").text
except (AttributeError):
  resolution = "0"
  ET.SubElement(data, "resolution").text = resolution

# load addon settings
# set defaults
cec_exit = "false"
evdev_exit = "false"
kodi_signals = "false"
fast_switching = "false"
tv_mode = "false"

try:
  settings_file = ET.parse(SETTINGS)
  settings = settings_file.getroot()
  for setting in settings:
    if setting.get("id") == "cec-exit":
      cec_exit = setting.text
    elif setting.get("id") == "evdev-exit":
      evdev_exit = setting.text
    elif setting.get("id") == "kodi-signals":
      kodi_signals = setting.text
    elif setting.get("id") == "fast-switching":
      fast_switching = setting.text
    elif setting.get("id") == "tv-mode":
      tv_mode = setting.text
except (IOError, AttributeError): # no file or corrupt so leave blank
  xbmc.log("retrOSMCmk2 Launcher: \"%s\" missing or corrupt on this run" % (SETTINGS), level=xbmc.LOGNOTICE)


# check an arg was actually passed to the script so it's all addon settings-page related
# differentiates from a launch situation
if len(sys.argv) > 1:
  MODE = sys.argv[1]
  SUBMODE = sys.argv[2]

# default action = launch ES +/- fast switch +/- CEC exit button +/- disable Kodi exit signals
else:
  # fast switching (Vero4k only) needs PulseAudio - brief user and install if absent
  if (fast_switching == "true"):
    # Vero4K implied as the option is only visible in settings on that platform
    pav = subprocess.Popen("pulseaudio --version", universal_newlines=True, stdout=subprocess.PIPE, shell=True)
    pav.wait()
    if pav.returncode != 0:
      # Pulse isn't installed yet, so give warning
      dialog.ok("PulseAudio", "Fast-Switching has been enabled.  This requires PulseAudio to be installed.  On a clean install this will not affect Kodi.\nBut if you are using BlueAlsa or similar you may run into problems.  If so, you can remove it from the settings menu.")
      install = dialog.yesno("PulseAudio", "Do you still want to install PulseAudio?\n\nIf not, Fast-Switching will just be disabled again.")
      if install == True:
        dialog.notification("retrOSMCmk2", "Installing PulseAudio\nPlease wait...", xbmcgui.NOTIFICATION_INFO, 8000)
        apti = subprocess.Popen("sudo apt-get install -y pulseaudio", universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        apti.wait()
        # check for success
        if apti.returncode == 0:
          dialog.notification("retrOSMCmk2", "PulseAudio installed.", xbmcgui.NOTIFICATION_INFO, 1500)
          time.sleep(2)
        else:
          so, se = apti.communicate()
          dialog.ok("PulseAudio", "Error installing PulseAudio!\n%s" % (se))
          exit()

      else:
        dialog.notification("retrOSMCmk2", "Fast-Switching disabled.", xbmcgui.NOTIFICATION_INFO, 1500)
        time.sleep(2)
        # continue with slow switching
        fast_switching = "false"
        # disable fast-switching in settings
        for setting in settings:
          if setting.get("id") == "fast-switching":
            setting.text = fast_switching
        xmlstr = ET.tostring(settings).decode()
        newxml = MD.parseString(xmlstr)
        with open(SETTINGS,"w+") as outfile:
          outfile.write(newxml.toprettyxml(indent="",newl=""))

  # configure go button for menu
  if (fast_switching == "true"):
    go_button = 'Start New Session'
  else:
    go_button = 'Launch!'

  # disable Estuary-based design explicitly
  pyxbmct.skin.estuary = False # go retro - obviously!

  # get currently active slots from app-switcher via FIFO
  os.system('echo "dump" > %s' % (SWITCHER_FIFO))
  time.sleep(0.1) # don't want to read our own request from the FIFO!
  msg = read_FIFO(SWITCHER_FIFO)

  # should have received ":" seperated paired list of labels, with num of pairs as first element
  labels_master = msg.split(':')
  slots_master = int(labels_master.pop(0))
  size = len(labels_master)
  if (slots_master != size / 2) or (size % 2 != 0):
    exit() # corrupt data received

  while True:
    labels = labels_master[:]
    slots = slots_master

    # display session manager
    target_slot = -1
    if __name__ == '__main__':
      window = slotManager("retrOSMCmk2 - Session Manager")
      window.doModal()
      del window
      # effectively refresh the screen after deleting a session slot (-2)
      if target_slot == -2:
        pass
      else:
        break


  if target_slot == -1:
    exit() # backed out of session manager without choosing anything

  # something to look at whilst Kodi is shutting down
  if (kodi_signals == "false" and fast_switching == "false"):
    xbmc.executebuiltin("ActivateWindow(busydialognocancel)")

  # start the CEC exit button watchdog?
  if cec_exit == "true":
    os.system('systemctl start cec-exit')

  # start the evdev exit button watchdog?
  if evdev_exit == "true":
    os.system('systemctl start evdev-exit')

  # switch TV mode at launch?
  if (tv_mode == "false"):
    resolution = 0

  # launch Emulationstation +/- fast switching which is needed to block CEC shutdown signals too
  if (kodi_signals == "true" or fast_switching == "true"):
    os.system('echo "switch es fast %s %s" >/tmp/app-switcher.fifo' % (target_slot, resolution))
  else:
    os.system('echo "switch es slow 0 %s" >/tmp/app-switcher.fifo' % (resolution))

  exit()
  # RetroPie launched - we are gone

# if we are here then it wasn't a launch, but a request from the settings menu
# parse arguments for required mode
if MODE == "CEC":
  if SUBMODE == "PROGRAM":
    dialog.ok("Program Exit Key", "1. Press OK\n\n2. Repeatedly press the button on your TV remote that you want to exit RetroPie.")
    remote_jammer("START")
    cec_client("START")
    dialog.notification("CEC-client", "listening...", xbmcgui.NOTIFICATION_INFO, 1000)

    # collect 2 presses of the same key and the description that follows if it exists
    keys = [keycode]
    while not keys.count(keys[-1]) == 2:
      keys.append(cec_client("CODE"))

    keycode = keys[-1]
    keydesc = cec_client("DESC")

    # write out addon data.xml
    data.find("keycode").text = keycode
    data.find("keydesc").text = keydesc
    xmlstr = ET.tostring(data).decode()
    newxml = MD.parseString(xmlstr)
    with open(DATA,"w+") as outfile:
        outfile.write(newxml.toprettyxml(indent="",newl=""))

    cec_client("STOP")
    remote_jammer("STOP")
    dialog.ok("CEC-client", "Keycode = %s\nDescription = %s" % (keycode, keydesc))


  elif SUBMODE == "SETTING":
    dialog.ok("Current CEC Keycode", "Code = %s\nDescription = %s" % (keycode, keydesc))

  elif SUBMODE == "TEST":
    if keycode == "No keycode set yet!":
      dialog.ok("Test Exit Key", "Code = %s\nDescription = %s" % (keycode, keydesc))
    else:
      dialog.ok("Test Exit Key", "1. Press OK\n\n2. Repeatedly press the button on your TV remote that you have set to exit RetroPie.")
      remote_jammer("START")
      cec_client("START")
      dialog.notification("CEC-client", "listening...", xbmcgui.NOTIFICATION_INFO, 1000)

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

  else:
    xbmc.log("ERROR!\n\"%s\" is a bad SUBMODE for %s" % (SUBMODE, sys.argv[0]), level=xbmc.LOGNOTICE)

elif MODE == "EVDEV":
  # helper will automatically grab the device when testing to avoid a clash with Kodi - no jammer needed here

  # ensure FIFO is in place for evdev-helper comms
  if not path.exists(EVDEV_FIFO):
    os.mkfifo(EVDEV_FIFO)

  if SUBMODE == "PROGRAM":
    dialog.textviewer("Program Exit Buttons", "These will work like RetroPie.\n\nYou configure a hotkey enable button and an exit button.  For example to exit back to Emulationstation most people are configured to hold down \"select\" and press \"start\".\n\nThe enable button could be the same as RetroPie, but the switch button MUST NOT ALREADY BE ASSIGNED to anything else in RetroPie e.g. exit, reset, save/load gamestate.\n\nProgramming instructions\n1. Press OK\n2. When requested press the hotkey enable button on the gamepad.\n3. Then when requested press the gamepad button you will use for the switching function.")

    # collect controller name and hotkey enable button
    subprocess.Popen([EVHELPER, "SCANMULTI"])
    dialog.notification("Program Exit Buttons", "Press hotkey enable button...", xbmcgui.NOTIFICATION_INFO, 3000)
    msg = read_FIFO(EVDEV_FIFO)
    # validate output = gamepad-id:button-id
    gamepad = msg.split(':', 1)[0]
    hotbtncode = msg.split(':', 1)[1]
    dialog.notification("Program Exit Buttons", "Button captured!", xbmcgui.NOTIFICATION_INFO, 2000)
    time.sleep(3)

    # collect exit button for the same controller
    subprocess.Popen([EVHELPER, "SCANSINGLE", gamepad, "PARENT"])
    dialog.notification("Program Exit Buttons", "Press exit button...", xbmcgui.NOTIFICATION_INFO, 3000)
    msg = read_FIFO(EVDEV_FIFO)
    # validate output - gamepad id, button id
    if not msg.split(':', 1)[0] == gamepad:
      dialog.ok("Program Exit Buttons", "\"Exit Button\" must be on the same controller as the \"Hotkey Enable Button\"!")
      exit()

    exitbtncode = msg.split(':', 1)[1]
    # exit button cannot be the same as the hotkey enable button...
    if exitbtncode == hotbtncode:
      dialog.ok("Program Exit Buttons", "\"Exit Button\" cannot be the same as the \"Hotkey Enable Button\"!")
      exit()

    # write out addon data.xml
    data.find("gamepad").text = gamepad
    data.find("hotbtncode").text = hotbtncode
    data.find("exitbtncode").text = exitbtncode
    xmlstr = ET.tostring(data).decode()
    newxml = MD.parseString(xmlstr)
    with open(DATA,"w+") as outfile:
        outfile.write(newxml.toprettyxml(indent="",newl=""))

    dialog.ok("New EVDEV Exit Settings", "Gamepad:\n%s\nHotkey enable button = %s\nExitkey enable button = %s" % (gamepad, hotbtncode, exitbtncode))


  elif SUBMODE == "SETTING":
    dialog.ok("Current EVDEV Exit Settings", "Gamepad:\n%s\nHotkey enable button = %s\nExitkey enable button = %s" % (gamepad, hotbtncode, exitbtncode))


  elif SUBMODE == "TEST":
    if hotbtncode == "No button code set yet!":
      dialog.ok("Test Exit Buttons", "%s" % (hotbtncode))
    else:
      dialog.ok("Test Exit Buttons", "1. Press OK\n\n2. On the gamepad hold the hotkey enable button, then press the exit button.")

      # test exit button combination
      subprocess.Popen([EVHELPER, "CATCHCOMBO", "TEST", gamepad, hotbtncode, exitbtncode])
      dialog.notification("Testing Exit Buttons", "Press exit combination...", xbmcgui.NOTIFICATION_INFO, 3000)
      msg = read_FIFO(EVDEV_FIFO)
      if msg == "EXIT":
        dialog.ok("Test Exit Buttons", "Exit combination detected correctly!")
      elif msg == "TIMEOUT":
        dialog.ok("Test Exit Buttons", "Exit combination was not detected!")

  else:
    xbmc.log("ERROR!\n\"%s\" is a bad SUBMODE for %s" % (SUBMODE, sys.argv[0]), level=xbmc.LOGNOTICE)

elif MODE == "RES":
  if SUBMODE == "PROGRAM":
    # obtain current video mode number
    tvs_proc = subprocess.Popen([TVSERVICE, "-s"], stdout=subprocess.PIPE)
    so, se = tvs_proc.communicate()
    current_mode = so.split('(', 1)[1].split(')')[0]
    chosen_mode = resolution # from config

    # obtain available modes
    mode_refs = []
    tvs_proc = subprocess.Popen([TVSERVICE, "-m","CEA"], stdout=subprocess.PIPE)
    so, se = tvs_proc.communicate()
    # newline seperated list
    available_modes = so.split("\n")
    # remove first title line and last blank line
    available_modes.pop(0)
    available_modes.pop(len(available_modes)-1)
    # for each mode line
    for line in range(0, len(available_modes)-1):
      # extract and store mode number
      mode = available_modes[line].split('mode ', 1)[1].split(':')[0]
      mode_refs.append(mode)
      # then  mark the active and selected
      if mode == chosen_mode:
        available_modes[line] = available_modes[line] + "  <- SELECTED"
      elif mode == current_mode:
        available_modes[line] = available_modes[line] + "  <- ACTIVE"
      # remove leading "mode n: "
      available_modes[line] = available_modes[line].split(": ")[1]

    # present list for user to select
    chosen_mode = dialog.select("Select TV mode for launch", available_modes)
    xbmc.log(str(chosen_mode), level=xbmc.LOGNOTICE)
    # exit if nothing selected
    if chosen_mode == -1:
      exit()
    # or if the active TV mode selected as trying to set that loses the signal
    elif mode_refs[chosen_mode] == current_mode:
      exit()

    # test mode for 5s
    dialog.ok("Mode Test", "The selected mode will now be displayed for 5 seconds just to confirm it works, but the display will likely be zoomed")
    cmd_str = '%s -e "CEA %s"' % (TVSERVICE, mode_refs[chosen_mode])
    tvs_proc = subprocess.Popen(cmd_str, universal_newlines=True, stdout=subprocess.PIPE, shell=True)
    time.sleep(7)
    cmd_str = '%s -e "CEA %s"' % (TVSERVICE, current_mode)
    tvs_proc = subprocess.Popen(cmd_str, universal_newlines=True, stdout=subprocess.PIPE, shell=True)

    # save config if acceptable
    keep = dialog.yesno("Mode Test", "Keep that mode for launching Emulationstation?")
    if keep == True:
      # write out addon data.xml
      data.find("resolution").text = mode_refs[chosen_mode]
# TODO move saving to a generic function
      xmlstr = ET.tostring(data).decode()
      newxml = MD.parseString(xmlstr)
      with open(DATA,"w+") as outfile:
          outfile.write(newxml.toprettyxml(indent="",newl=""))

  else:
    xbmc.log("ERROR!\n\"%s\" is a bad SUBMODE for %s" % (SUBMODE, sys.argv[0]), level=xbmc.LOGNOTICE)

elif MODE == "PULSE":
  if SUBMODE == "REMOVE":
    # check Pulse is actually there to be removed
    pav = subprocess.Popen("pulseaudio --version", universal_newlines=True, stdout=subprocess.PIPE, shell=True)
    pav.wait()
    if pav.returncode != 0:
      # Pulse wasn't actually installed!
      dialog.ok("PulseAudio", "PulseAudio isn't installed!")
      exit()

    uninstall = dialog.yesno("PulseAudio", "This will uninstall PulseAudio.\n\nAre you sure?")
    if uninstall == True:
        dialog.notification("retrOSMCmk2", "Removing PulseAudio.\nPlease wait...", xbmcgui.NOTIFICATION_INFO, 6000)
        aptr = subprocess.Popen("sudo apt-get remove -y pulseaudio", universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        # check for success
        aptr.wait()
        if aptr.returncode == 0:
          dialog.notification("retrOSMCmk2", "PulseAudio removed.", xbmcgui.NOTIFICATION_INFO, 1500)
        else:
          so, se = aptr.communicate()
          dialog.ok("PulseAudio", "Error removing PulseAudio!\n%s" % (se))

  else:
    xbmc.log("ERROR!\n\"%s\" is a bad SUBMODE for %s" % (SUBMODE, sys.argv[0]), level=xbmc.LOGNOTICE)

else:
  xbmc.log("ERROR!\n\"%s\" is a bad MODE for %s" % (MODE, sys.argv[0]), level=xbmc.LOGNOTICE)

#  xbmc.log("DEBUG: ", level=xbmc.LOGNOTICE)
