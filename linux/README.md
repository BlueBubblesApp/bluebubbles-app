# Linux Install Instructions (using install script)
These instructions have been verified on Ubuntu 20.04. They should work on most distros but your mileage may vary.
1. Download the `bluebubbles_linux.zip` file from the most recent release
2. Donwload the `install.sh` script into the same directory
3. Download the `Bluebubbles.desktop` file into the same directory
4. `cd` into that directory
5. Run `chmod +x ./install.sh`
6. Run `sudo ./install.sh`

# Instuctions for Setting Up your Desktop File For BlueBubbles in Linux Manually
1. In `Bluebubbles.desktop` change exec to the location of the `bluebubbles_app`
2. Edit the icon to the location of the icon usually in `flutter_assets`
3. Move `Bluebubbles.desktop` to `/usr/share/applications` (or where ever your applications folder is)
