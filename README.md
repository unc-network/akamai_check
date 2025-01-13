# akamai_check

**Author:** Will Whitaker (will.whitaker@unc.edu)

**Description:** Detect and respond to failing Akamai forwarders with Infoblox.

## Monitoring

In some situations, Akamai DNS has failed while Internet access remained up.  In those situations, a script running on a server will test DNS and manipulate DNS Forwarding configurations in Infoblox accordingly.  This script is expected to work when DNS is actually broken so it has been intentionally written as such.

## Crontab

The root crontab on NIT contains the script and a task to clean up old log files.

~~~~
# Akamai check
* * * * *       /home/wew/bin/akamai_check.sh > /home/wew/log/`date +\%Y\%m\%d\%H\%M\%S`_akamai_check.log
0 8 * * *       find /home/wew/log/*.log -mtime +7 -type f -delete
~~~~

## Example Run

This was run against Infoblox test grid which was configured in the file.

~~~~
[wew@nit bin]$ ./akamai_check.sh 
Starting Akamai forwarding tests at Thu Aug  3 07:22:20 EDT 2023
Test query: google.com
---
Starting loop 0
88.221.162.177 lookup success
88.221.163.178 lookup success
8.8.8.8 lookup success
9.9.9.9 lookup success
1.1.1.1 lookup success
---
Starting loop 1
88.221.162.177 lookup success
88.221.163.178 lookup success
8.8.8.8 lookup success
9.9.9.9 lookup success
1.1.1.1 lookup success
---
Starting loop 2
88.221.162.177 lookup success
88.221.163.178 lookup success
8.8.8.8 lookup success
9.9.9.9 lookup success
1.1.1.1 lookup success
---
Starting loop 3
88.221.162.177 lookup success
88.221.163.178 lookup success
8.8.8.8 lookup success
9.9.9.9 lookup success
1.1.1.1 lookup success
---
Starting loop 4
88.221.162.177 lookup success
88.221.163.178 lookup success
8.8.8.8 lookup success
9.9.9.9 lookup success
1.1.1.1 lookup success
---
Akamai forwarding was bad 0 out of 5 loops
===
Checking if view Guest needs to be updated
Guest is set with use_forwarders = true
No updates are necessary in the View Guest
Checking if view Internal needs to be updated
Internal is set with use_forwarders = true
No updates are necessary in the View Internal
===
Infoblox forwarding was not updated on 152.9.5.6
~~~~
