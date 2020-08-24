iostat -c | sed '4q;d' | awk '{print "cpuuser=" $1 "\r\n" "cpusystem=" $3 "\r\n" "cpuidle=" $6 }' #cpuusage
echo "cpuclockspeed=666"
echo "cputemp=38.0"
cat /proc/meminfo | sed '3q' | awk '{print $1 $2}' | sed 's/:/=/' #memoryusage
df | grep "/dev/sda1" | awk '{print "drivetotalmb=" $2/1024 "\r\ndriveusedmb=" $3/1024 "\r\ndriveavailablemb=" $4/1024}' #disk usage
iostat -d | grep "sda" | awk '{print "drivekbreads="$3"\r\ndrivekbwrites="$4 }' #disk IO stats
ifstat -i enp3s0  0.1 1 | sed '3q;d' | awk '{print "networkkbin=" $1 "\r\nnetworkkbout=" $2}' #network usage
uptime -s | awk '{print "systemuptime="$1, $2}'