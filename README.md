This is a Docker version of sfeakes' AqualinkD program, modified to use an EW-11 RS485-over-wifi module to connect to Jandy Aqualink pool controller.

Edit the aquaexec-pre.sh file in config folder to update your EW-11's IP and port

Edit aqualinkd.conf file in config folder to match your pool configuration and set up your MQTT parameters

Upload all of the files to a folder called "aqualinkd" in the addons folder in Home Assistant

Go to Addons, addon store, select the AqualinkD addon, install, then run.  You will need to enable watchdog to restart if the container crashes.

I will add screenshots later of my dashboard, along with the configuration I added to my configuration.yaml file and template helpers to make it all work.
