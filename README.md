# Supermicro X10 Fancontrol

## Summary

This script is used to dynamically control the fan duty cycle (speed) on a Supermicro X10 server by calculating the current percentage of the maximum operating temperature of a CPU and setting the duty cycle of the fans to the equivalent percentage of their maximum speed. 

For example, if your CPU's maximum operating temperature is 79°C, and the current reading is 40 is is at ~51% of the threshold. The fan speeds will then be set to 51% accordingly. If the desired duty cycle results in a lower RPM than the Lower Critical threshold of the fans in the pool, the Lower Critical treshold will be used as the duty cycle instead to avoid the BMC overriding the configuraiton. To find this value, use `ipmitool sensor | grep FAN | awk '{print $11}'`

<hr>

## Requirements

| Package      | Description                                                  |
| ------------ | ------------------------------------------------------------ |
| `jq`         | Used to parse the output of `lm-sensors` for a specific sensor value |
| `lm-sensors` | Used to collect data on sensors                              |
| `ipmitool`   | Used to get and set fan duty cycle configurations            |

<hr>

## Configuration

| Variable           | Description                                                |
| ------------------ | ---------------------------------------------------------- |
| `SLEEP_INTERVAL`   | The amount of time to sleep between script executions      |
| `CPU_MAX_TEMP`     | The maximum operating temperature of your CPU              |
| `FAN_LC_THRESHOLD` | The lowest Lower Critical value of fans in the system pool |
| `SENSOR_JSONPATH`  | The JSONPath to the desired sensor to monitor              |

<hr>

## Installation

```bash
cp fancontrol /usr/bin/fancontrol
chmod +x /usr/bin/fancontrol
cp fancontrol.service /etc/systemd/system/fancontrol.service
systemctl enable --now fancontrol
```

<hr>

## Example Output

```bash
$> journalctl -xefu fancontrol

Sep 17 12:25:59 earth fancontrol[181096]: -----Sun Sep 17 12:25:59 PM PDT 2023-----
Sep 17 12:25:59 earth fancontrol[181096]: INFO - Current temperature: 37/79°C (46%)
Sep 17 12:25:59 earth fancontrol[181096]: INFO - Current duty cycle:  29/64
Sep 17 12:25:59 earth fancontrol[181096]: INFO - Setting duty cycle:  29/64
Sep 17 12:26:04 earth fancontrol[181096]: -----Sun Sep 17 12:26:04 PM PDT 2023-----
Sep 17 12:26:04 earth fancontrol[181096]: INFO - Current temperature: 40/79°C (50%)
Sep 17 12:26:04 earth fancontrol[181096]: INFO - Current duty cycle:  29/64
Sep 17 12:26:04 earth fancontrol[181096]: INFO - Setting duty cycle:  32/64
Sep 17 12:26:10 earth fancontrol[181096]: -----Sun Sep 17 12:26:10 PM PDT 2023-----
Sep 17 12:26:10 earth fancontrol[181096]: INFO - Current temperature: 46/79°C (58%)
Sep 17 12:26:10 earth fancontrol[181096]: INFO - Current duty cycle:  32/64
Sep 17 12:26:10 earth fancontrol[181096]: INFO - Setting duty cycle:  37/64
Sep 17 12:26:16 earth fancontrol[181096]: -----Sun Sep 17 12:26:16 PM PDT 2023-----
Sep 17 12:26:16 earth fancontrol[181096]: INFO - Current temperature: 47/79°C (59%)
Sep 17 12:26:16 earth fancontrol[181096]: INFO - Current duty cycle:  37/64
Sep 17 12:26:16 earth fancontrol[181096]: INFO - Setting duty cycle:  37/64
Sep 17 12:26:23 earth fancontrol[181096]: -----Sun Sep 17 12:26:23 PM PDT 2023-----
Sep 17 12:26:23 earth fancontrol[181096]: INFO - Current temperature: 48/79°C (60%)
Sep 17 12:26:23 earth fancontrol[181096]: INFO - Current duty cycle:  37/64
Sep 17 12:26:23 earth fancontrol[181096]: INFO - Setting duty cycle:  38/64
Sep 17 12:26:29 earth fancontrol[181096]: -----Sun Sep 17 12:26:29 PM PDT 2023-----
Sep 17 12:26:29 earth fancontrol[181096]: INFO - Current temperature: 49/79°C (62%)
Sep 17 12:26:29 earth fancontrol[181096]: INFO - Current duty cycle:  38/64
Sep 17 12:26:29 earth fancontrol[181096]: INFO - Setting duty cycle:  39/64
Sep 17 12:26:36 earth fancontrol[181096]: -----Sun Sep 17 12:26:36 PM PDT 2023-----
Sep 17 12:26:36 earth fancontrol[181096]: INFO - Current temperature: 50/79°C (63%)
Sep 17 12:26:36 earth fancontrol[181096]: INFO - Current duty cycle:  39/64
Sep 17 12:26:36 earth fancontrol[181096]: INFO - Setting duty cycle:  40/64
```
