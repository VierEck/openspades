# OpenSpades+

## What is it?
OpenSpades+ is a modification of [OpenSpades](https://github.com/yvt/openspades) that has

* No FOV cap (use cg_fov)
* No falling blocks hindering visibility
* A crosshair more akin to classic FPS games such as CS:GO
* No ragdolls or corpses whatsoever
* More information on kills where the killing blow was a headshot 
* More concise kill and death messages both as the center message log and kill log

## How to build?
[Just build like normal OpenSpades.](https://github.com/yvt/openspades/wiki/Building)
If you are on Linux and have all the dependencies installed there is a convenient [file](https://github.com/nonperforming/openspadesplus/blob/master/build.sh) that will run all the necessary commands to build OpenSpades+.

## Useful console variables
### cg_ejectBrass
Recommended: 0

This turns off those bullet casings when you fire. They disappear after a second or two, so they aren't really useful outside of cosmetic purposes.

### cg_viewWeaponX, cg_viewWeaponY, cg_viewWeaponZ
Recommended: cg_viewWeaponY -100

This hides your viewmodel to give you extra visibility.

### cg_particles
Recommended: 0

As simple as it gets. Turn particles on or off along with some extra stuff. This can and will hide grenade particles, which may be useful.

### r_vsync
Recommended: 0

Unlimit refresh rate and decrease input delay. THIS WILL CRASH IN-GAME, TUNE IN STARTUP SETTINGS

### cl_fps
Recommended: 0

No FPS cap.

### cg_environmentalAudio
Recommended: 1

This turns on those fancy calculations for more precise and accurate sound.

### cg_fov
Recommended: N/A

FOV is very a preferential thing. Nobody's judging you, go crazy and set it to 1 or 179
