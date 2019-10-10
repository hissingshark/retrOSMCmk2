import os, subprocess, time

# Interrupt Kodi sending any "standby" messages to a TV/AVR when we stop mediacenter.service later
cecc = subprocess.Popen("/usr/osmc/bin/cec-client", stdout=subprocess.PIPE, universal_newlines=True)
time.sleep(1)

# launch RetroPie
os.system('systemctl start emulationstation.service')
time.sleep(1)

# stop cec-client
cecc.terminate()
cecc.communicate()

