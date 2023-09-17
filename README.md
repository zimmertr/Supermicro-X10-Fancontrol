# IPMITool Fancontrol

## Summary

This script can be used to dynamically control the CPU/System fan duty cycle on a Proxmox server. It works by retrieving the current average CPU temperature and calculating the percentage of the maximum operating temperature and setting the fan "duty cycle" speed to an equivalent percentage. 

EG: If your current average CPU Temperature is 41, and the maximum operating temperature is 79, then the fan duty cycle speed will be set to (41 / 79 = 51%) of the maximum hexadecimal value, 64, (32) 

## Instructions

1. Install requirements:
   1. `apt-install jq lm-sensors ipmitool`
   2. `sensors-detect`
2. Install the script
   1. `cp fancontrol.sh /usr/bin/fancontrol.sh`
   2. cp `fanctronl.service /etc/systemd/system/fancontrol.service`
   3. `systemctl enable --now fancontrol`