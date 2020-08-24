# Pi Monitor

![Image of pimonitor](https://i.imgur.com/ztGXqvr.png)

This is a simple monitoring server intended for a raspberry pi (though you could run this on any linux machine).

It is written in ruby and requires the `Victor` and `Minichart` svg generation gem (https://github.com/DannyBen/victor). `gem install minichart` will cover both.

# Installation

1) Download this repo
2) Open server.rb and set the TCPServer port to whatever IP and port you want the server to bind to (it defaults to "localhost")
3) Open the /monitorstatgen/ folder and create a folder named "stats". The program should create this but sometimes permissions are strange.
4) Test run the statgen.sh file, to make sure your pi has the tooling available to generate the stats required. If you are missing tools, install them. By default, you need `iostat`, `vcgencmd`, `cat`, `df`, `iostat`, `ifstat`, `uptime`, `awk` and `grep`. Most of these are available in any distro.
6) Optionally, you can open logging.rb and set the log level. It defaults to DEBUG.
7) Optionally, you can open statsgen.rb and set the statsInterval (how often stats are collected), and the statCutoff (how long before old stats are purged)
8) Run the server with `ruby server.rb`
9) Visit `{host}:{port}/monitor` to view the graphs 

# Troubleshooting and Known Issues

#### "some" directory does not exist
For some reason, not every linux system will let you create directories when saving a file. Create the directory manually and make sure you have permissions to it.

#### Nil value error in statgen.rb
Again, this is a particular OS quirk. There need to be at least 2 statfiles available to generate the charts. The program tries to check to make sure there are, but some linux OS's do not correctly report the contents of directories and this check fails. Just run the program again.

This can also be caused by an incomplete statfile. Your statfile(s) should look like this, with different values of course:

```
cpuuser=2.82
cpusystem=0.61
cpuidle=96.56
cpuclockspeed=666
cputemp=38.0
MemTotal=8112384
MemFree=4229364
MemAvailable=5335232
drivetotalmb=441642
driveusedmb=5485.25
driveavailablemb=413654
drivekbreads=48.87
drivekbwrites=61.77
networkkbin=27.40
networkkbout=1226.51
systemuptime=2020-08-23 20:23:09
```

If some values are blank or missing entirely, modify the statgen.sh file to fix the problem (most likely you are missing a program, or have a device with a strange name, or are trying to run vcgencmd commands on a non-raspberry pi machine). If any values are missing, the program is very likely to fail, or at least generate incorrect stats. They are all used for something.


#### pimonitor.service cannot resolve `./some/relative/dir`
You *can* run this as a service using `systemd`. You need to set the WorkingDirectory to the base path you copied the files to (ex: `/home/you/pimonitor`). You also need to include the ruby binary in the Exec path (ex: `Exec=/usr/bin/ruby /home/you/pimonitor/server.rb`). You additionally need to run this as a specific user (ex: `User=you`). I dont know why this last part is a requirement, but without it, it seems like it cannot resolve the relative directories required. 

