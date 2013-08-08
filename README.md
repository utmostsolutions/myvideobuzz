MyVideoBuzz
=============

This project is fork of https://github.com/jesstech/Roku-YouTube, it is updated to fix the API changes and added new features and removed OAuth settings.


Installation
============

Enable development mode on your Roku Streaming Player with the following remote 
control sequence:

    Home 3x, Up 2x, Right, Left, Right, Left, Right

When devleopment mode is enabled on your Roku, you can install dev packages
from the Application Installer which runs on your device at your device's IP
address. Open up a standard web browser and visit the following URL:

    http://<rokuPlayer-ip-address> (for example, http://192.168.1.6)

[Download the source as a zip](https://github.com/utmostsolutions/myvideobuzz/zipball/master) and upload it to your Roku device.

Due to limitations in the sandboxing of development Roku channels, you can only
have one development channel installed at a time.

Advanced
========

### Debugging

Your Roku's debug console can be accessed by telnet at port 8085:

    telnet <rokuPlayer-ip-address> 8085

### Building from source

The [Roku Developer SDK](http://www.roku.com/developer) includes a handy Make script 
for automatically zipping and installing the channel onto your device should you make
any changes.  Just add the project to your SDK's `examples/source` folder and run the
`make install` command from that directory via your terminal.


Contributing
------------

Want to contribute? Great! Please contact us http://www.myvideobuzz.in/