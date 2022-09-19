#!/bin/bash
#
# Check that script is running as root
if (( $(id -u) != 0 )); then
  echo -e 'Make sure you run the script as root.'
  exit 1
fi
# Check that Bluebubbles.desktop is present
if [ ! -f ./Bluebubbles.desktop ]; then
  echo -e 'Make sure Bluebubbles.desktop exists in the working directory'
  exit 1
fi
# Check that bluebubbles_linux.zip is present
if [ ! -f ./bluebubbles_linux.zip ]; then
  echo -e 'Make sure bluebubbles_linux.zip exists in the working directory'
  exit 1
fi


# Remove any old version of bluebubbles, if any
echo 'Removing old versions of Bluebubbles'
rm -rf /opt/bluebubbles_app/bundle
rm -f /usr/share/applications/Bluebubbles.desktop
rm -f /usr/lib/libobjectbox.so

# Unzip the bundle to /opt/bluebubbles_app/
echo 'Unzipping the Bundle to the install location'
mkdir -p /opt/bluebubbles_app/
unzip ./bluebubbles_linux.zip -d /opt/bluebubbles_app/

# Symlink libobjectbox to the correct place
ln -s /opt/bluebubbles_app/bundle/lib/libobjectbox.so /usr/lib/libobjectbox.so

# Make the binary executable and add it to a location on PATH
echo 'Making the Binary executable'
chmod +x /opt/bluebubbles_app/bundle/bluebubbles*
chmod -R 755 /opt/bluebubbles_app
rm -f /usr/local/bin/bluebubbles*
ln -s /opt/bluebubbles_app/bundle/bluebubbles* /usr/local/bin/bluebubbles
chmod +x /usr/local/bin/bluebubbles

# Setup the .desktop file
echo 'Setting up Bluebubbles.destkop file'
cp ./Bluebubbles.desktop /usr/share/applications/Bluebubbles.desktop
sed -i "s@/path/to@/opt/bluebubbles_app@" /usr/share/applications/Bluebubbles.desktop
chmod +x /usr/share/applications/Bluebubbles.desktop

echo 'Done! You may need to relog to see Bluebubbles in your applications menu.'
