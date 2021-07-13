# handle Kodi 18 -> 19 migration because of Python 2 -> 3
# the addon will be disabled by Kodi and so unable to update itself... so we'll have to wait for a reboot and catch the new version here
# this source file is removed thereafter to prevent rerun

if [[ "$(kodi --version | grep 19)" != "" ]]; then
  # modify addon to meet Python 3 requirements
  sed -i '/addon="xbmc.python"/s/version=".*"/version="3.0.0"/' /home/osmc/.kodi/addons/script.launch.retropie/addon.xml
  sed -i '/self.placeControl(self.new_btn, new_row/s/new_row/int(new_row)/' /home/osmc/.kodi/addons/script.launch.retropie/addon.py

  # delete this code to prevent subsequent runs
  rm /home/osmc/retrOSMCmk2/resources/matrix_migration.sh

  # restart Kodi so that the fixed addon can be re-enabled
  sudo systemctl restart mediacenter
fi
