# Pi Monitor

###### pimonitor stats during a 3 hour CPU benchmark test
![Image of pimonitor while the pi runs a CPU benchmark](https://i.imgur.com/w56jSzd.png)

This is a simple monitoring server intended for a raspberry pi, though you could run this on any linux machine. It provides a high level overview of CPU, RAM, Disk and Network resources on the machine, and is intended to be accessed remotely, generally within a network but can also be forwarded to the internet as well.

It is written in ruby and requires the `Victor` and `Minichart` svg generation gem (https://github.com/DannyBen/victor). `gem install minichart` will cover both.

It includes a simple web server, and a method to generate statistics and graphs. Both of these may be expanded, or may be used "as-is" to generate the page seen above. The web server will serve anything in the `./content` folder, though it currently has no support for dynamic content beyond its own monitor page.

# Installation

1) Download this repo
2) Open server.rb and set the TCPServer values to whatever IP and port you want the server to bind to (it defaults to `localhost` and `6689`)
3) Open the /monitorstatgen/ folder and create a folder named "stats". The program should create this but sometimes permissions are strange.
4) Test run the `statgen.sh` file, to make sure your pi has the tooling available to generate the stats required. If you are missing tools, install them. By default, you need `iostat`, `vcgencmd`, `cat`, `df`, `iostat`, `ifstat`, `uptime`, `awk` and `grep`. Most of these are available in any distro, except `vcgencmd` which is unique to Raspbian.
6) Optionally, you can open logging.rb and set the log level. It defaults to DEBUG. An appropriate "production" setting would be WARN.
7) Optionally, you can open statsgen.rb and set the statsInterval (how often stats are collected), and the statCutoff (how long before old stats are purged)
8) Run the server with `ruby server.rb`
9) Visit `{host}:{port}/monitor` to view the graphs 

# Questions and Troubleshooting

#### This uses too many resources!
If you have an older pi, the way stat generation works might be a little resource intensive. You can try to use the `server_classic.rb` and `statsgen_classic.rb` instead, just backup `server.rb` and `statsgen.rb` and then rename the `_classic` files to replace them. You will also probably need to update `statgen.sh` as these files are fairly old at this point, and a lot of things have changed. Alternative, clone from commit [6527632](https://github.com/crabtruckington/pimonitorrb-pub/commit/6527632725d4979eb1330c46fd7e97b7ca5724af) which is the last commit before these methods were altered.

#### Is this OK to run from an SD Card booted pi?
No, I would not recommend this, at least without changes. The way stat generation works creates a lot of files, and rotates them fairly regularly (once you hit the cutoff date). Even though the files are small, SD cards do not have good reliability when written to and read constantly. I would recommend you use USB Boot from either a USB memory stick, or even better, an external hard drive or SSD. If those options are not available, you could tweak the stats frequency in `statsgen.rb` to generate more of a "snapshot" of statistics every few minutes, rather than every few seconds. Appropriate values might be something like `statsGenInterval = 300` and `@statCutoff = (60 * 60 * 24 * 14)` (5 minutes, and 14 days, respectively), and then change `genStatsPageEveryX` in `server.rb` to `1`.

#### "some" directory does not exist
For some reason, not every linux distro will let ruby create directories. These methods have been hardened as much as possible but it seems like there are still instances where it doesnt work properly. Create the directory manually and make sure you have permissions to it.

#### Nil value error in statgen.rb
Again, this is mainly caused by OS quirks. There need to be at least 2 statfiles available to generate the charts. The program tries to check to make sure there are, but some distros do not correctly report the contents of directories and this check fails. Just run the program again.

Another issue may be that you are using old stat files generated using the old shell script. Try purging the `stats` directory and starting fresh.

This can also be caused by an incomplete statfile. Your statfile(s) should look like this, with different values of course:

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

