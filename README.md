# Supermicro X10 Fancontrol

## Summary

This script is used to dynamically control the fan duty cycle (speed) on a Supermicro X10 server by calculating the current percentage of the maximum operating temperature of a CPU and setting the duty cycle of the fans to the equivalent percentage of their maximum speed. 

For example, if your CPU's maximum operating temperature is 79°C, and the current reading is 40 is is at ~51% of the threshold. The fan speeds will then be set to 51% accordingly. If the desired duty cycle results in a lower RPM than the Lower Critical threshold of the fans in the pool, the Lower Critical treshold will be used as the duty cycle instead to avoid the BMC overriding the configuraiton.

<hr>

## Requirements

| Package      | Description                                                  |
| ------------ | ------------------------------------------------------------ |
| `jq`         | Used to parse the output of `lm-sensors` for a specific sensor value |
| `lm-sensors` | Used to collect data on sensors                              |
| `ipmitool`   | Used to get and set fan duty cycle configurations            |

<hr>

## Configuration

| Variable           | Description                                                  |
| ------------------ | ------------------------------------------------------------ |
| `SLEEP_INTERVAL`   | The amount of time to sleep between script executions        |
| `CPU_MAX_TEMP`     | The maximum operating temperature of your CPU                |
| `FAN_LC_THRESHOLD` | The lowest Lower Critical value of fans in the system pool <br />To find: `ipmitool sensor | grep FAN | awk '{print $11}'` |
| `SENSOR_JSONPATH`  | The JSONPath to the desired sensor to monitor                |

<hr>

## Installation

```bash
cp fancontrol /usr/bin/fancontrol
chmod +x /usr/bin/fancontrol
cp fancontrol.service /etc/systemd/system/fancontrol.service
systemctl enable --now fancontrol
```