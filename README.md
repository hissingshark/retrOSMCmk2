# retrOSMCmk2
The latest RetroPie installer for OSMC

---
## Supports
1. RPi Zero, 1, 2, 3;
2. Vero4k/Vero4K+/VeroV.

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
Restart Kodi and install the launcher addon with `My Addons -> Install from zip file`.  You'll find the zip under "Home folder".

Step 6.
Check out the addon's settings page.  Options include:

All platforms-
1. CEC exit - so you can quit back to Kodi using a TV remote button.
2. evdev exit - so you can quit back to Kodi using a gamepad button combination.

Vero4K/4k+ only-

3. Disable CEC exit events - stops Kodi putting the TV into standby when launching ES (only needed if you have it set to do that when Kodi shuts down).
4. Fast switcher - keeps Kodi and RetroPie in memory so you can instantly toggle between them.  No need to wait for them to startup and shut down.  Also means you can switch over mid game.  This now allows up to 9 active sessions, so you can multiple games on the go.

Step 7.

Optional - configure you main gamepad in Kodi.  Makes moving between gaming and media much smoother as it'll be in your hands anyway!

Optional - add scripts to be executed when leaving and returning to kodi.  Store them at `/home/osmc/RetroPie/scripts/` and call them `kodi-starts.sh` and `kodi-stops.sh` repectively.

---
## KNOWN ISSUES:

1. CEC exit configures just fine in the setting page, but doesn't always work/exit on LG TVs.  Fine on Samsungs.  Manufacturers CEC implementations vary greatly.  I'm attempting to fix this for LGs. The evdev-exit is recommended anyway.
2. When returning to Kodi via fast switching - a CEC IR TV remote will take a few seconds to start working again.  If you've configured your gamepad as suggested to work in Kodi then you won't ever notice this, because you can just keep on navigating with what's still in your hands from leaving RetroPie.
3. If you return to Kodi and a second later the screen shows RetroPie it's not real.  Just press any navigation button to refresh the screen.  Working on a fix for that.
