# Pi Monitor

###### pimonitor stats during a 3 hour CPU benchmark test
![Image of pimonitor while the pi runs a CPU benchmark](https://i.imgur.com/3NkJSEB.png)

This is a simple monitoring server intended for a raspberry pi, though you could run this on any linux machine. It provides a high level overview of CPU, RAM, Disk and Network resources on the machine, and is intended to be accessed remotely, generally within a network but can also be forwarded to the internet as well.

A postGres installation is required.

It is written in ruby and requires the `Victor` and `Minichart` svg generation gem (https://github.com/DannyBen/victor). `gem install minichart` will cover both.

It includes a simple web server, and a method to generate statistics and graphs. Both of these may be expanded, or may be used "as-is" to generate the page seen above. The web server will serve anything in the `./content` folder, though it currently has no support for dynamic content beyond its own monitor page.

# Installation

1) Download this repo
2) Install `postgresql` packages for your distro, and create a table using the `sqlTables.sql` file
3) Open copy `configs.rb.example` to `configs.rb` and configure the values as appropriate
4) Test run the `statgen.sh` file, to make sure your pi has the tooling available to generate the stats required. If you are missing tools, install them. By default, you need `iostat`, `vcgencmd`, `cat`, `df`, `iostat`, `ifstat`, `uptime`, `awk` and `grep`. Most of these are available in any distro, except `vcgencmd` which is unique to Raspbian.
7) Run the server with `ruby server.rb`
8) Visit `{host}:{port}/monitor` to view the graphs 

# Questions and Troubleshooting

#### This uses too many resources!
Originally the program used flat files. You can clone from commit [6527632](https://github.com/crabtruckington/pimonitorrb-pub/commit/6527632725d4979eb1330c46fd7e97b7ca5724af) before it was massively reworked. This was much lighter on resources. Of course, its unspported.

#### Is this OK to run from an SD Card booted pi?
I would not recommend it. Since it uses postgres, there is going to be quite a bit of drive activity. It would be better to run from a more reliable storage type.

#### "some" directory does not exist
For some reason, not every linux distro will let ruby create directories. These methods have been hardened as much as possible but it seems like there are still instances where it doesnt work properly. Create the directory manually and make sure you have permissions to it.

#### Nil value error in statgen.rb
This seems to happen on a fresh start, with absolutely nothing in the database. Just let it run again and it should generate stats correctly.

However, this can also be caused by an incomplete statfile. Your statfile(s) should look like this, with different values of course:

```
cpuused=42.2
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
systemuptime=up 1 day, 10 hours, 47 minutes
```

If some values are blank or missing entirely, modify the statgen.sh file to fix the problem (most likely you are missing a program, or have a device with a strange name, or are trying to run vcgencmd commands on a non-raspberry pi machine). If any values are missing, the program is very likely to fail, or at least generate incorrect stats. They are all used for something.


#### pimonitor.service cannot resolve `./some/relative/dir`
You *can* run this as a service using `systemd`. You need to set the WorkingDirectory to the base path you copied the files to (ex: `/home/you/pimonitor`). You also need to include the ruby binary in the Exec path (ex: `Exec=/usr/bin/ruby /home/you/pimonitor/server.rb`). You additionally need to run this as a specific user (ex: `User=you`). I dont know why this last part is a requirement, but without it, it seems like it cannot resolve the relative directories required. 

