This addon is an Emulationstation launcher for Kodi - cobbled together by Hissingshark

It is intended to be run under OSMC on the Vero4k or RPi 1-3.

Options include:

All platforms-
1. CEC exit - so you can quit back to Kodi using a TV remote button.
2. evdev exit - so you can quit back to Kodi using a gamepad button combination.

Vero4K/4k+ only-
3. Disable CEC exit events - stops Kodi putting the TV into standby when launching ES (only needed if you have it set to do that when Kodi shuts down).
4. Fast switcher - keeps Kodi and RetroPie in memory so you can instantly toggle between them.  No need to wait for them to startup and shut down.  Also means you can switch over mid game.  This now allows up to 9 active sessions, so you can multiple games on the go.

KNOWN ISSUES:

1. CEC exit configures just fine in the setting page, but doesn't always work/exit on LG TVs.  Fine on Samsungs.  Manufacturers CEC implementations vary greatly.  I'm attempting to fix this for LGs. The evdev-exit is recommended anyway.
2. When returning to Kodi via fast switching a CEC IR TV remote will take a few seconds to start working again.  If you've configured your gamepad as suggested to work in Kodi then you won't ever notice this, because you can just keep on navigating with what's still in your hands from leaving RetroPie.
3. If you return to Kodi and a second later the screen shows RetroPie it's not real.  Just press any navigation button to refresh the screen.  Working on a fix for that.


Installation is via the RetroPie installer:
https://github.com/hissingshark/retrOSMCmk2
