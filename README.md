# retrOSMCmk2
The latest RetroPie installer for OSMC

---
## Supports
1. RPi Zero, 1, 2, 3;
2. Vero4k/Vero4K+.

---
## Function
1. Install and launch the RetroPie-Setup scripts, to make a RetroPie system on a supported OSMC box;
2. Install a launcher addon, to start EmulationStation from Kodi;
3. Perform updating of the above utilities.

---
## Installation
From the console:

Step 1.
``` bash
sudo apt-get install git
git clone https://github.com/hissingshark/retrOSMCmk2.git
cd retrOSMCmk2
sudo ./setup.sh
```

Step 2.  
Select `Run RetroPie-Setup`

Step 3.  
a)
_EITHER_ install the "core packages" (Retroarch, EmulationStation, RetroPieMenu & Runcommand):  
`Manage packages -> Manage core packages -> Install/Update all core packages from binary`

b)
_OR_ select `Basic install` (all of the Core and Basic packages)

Step 4.  
Install additional emulators:  
`Manage packages -> Manage basic / optional / experimental packages`

Step 5.  
Restart Kodi and activate the launcher addon in `My Addons -> Programs`
