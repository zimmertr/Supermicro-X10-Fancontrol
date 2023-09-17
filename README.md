# Supermicro X10 Fancontrol

## Summary

This script is used to dynamically control the fan duty cycle (speed) on a Supermicro X10 server by calculating the current percentage of the maximum operating temperature of a CPU and setting the duty cycle of the fans to the equivalent percentage of their maximum speed. 

For example, if your CPU's maximum operating temperature is 79°C, and the current sensor reading is 40°C, it is at ~51% of the maximum. The fan speeds will then be set to 51% accordingly. If the current CPU temperature exceeds the desired CPU threshold temperature, the CPU threshold duty cycle will be used instead. If the desired duty cycle results in a lower RPM than the Lower Critical threshold of the fans in the pool, the Lower Critical treshold will be used as the duty cycle instead.

To find the maximum operating temperature and the ideal threshold temperature of a CPU, consult it's production specifications. To find the Lower Critical threshold of the fans, use `ipmitool sensor | grep FAN` and review the values in the 6th column. To the find correlated duty cycle value, use `ipmitool raw 0x30 0x70 0x66 0x01 0x00 0x##` with progressively lower integers until the set duty cycle drops the fan RPMs below the Lower Critical threshold and the BMC overrides the configuration. If you wish, you can customize these thresholds to set a lower or higher value with `ipmitool sensor thresh "FAN#" lower ### ### ###`. I use `100 300 500` with a pool of Noctua A12x25 fans and my server is virtually silent. 

**Be careful with this, and don't blame me if you melt down your server.**

<hr>

## Requirements

| Package      | Description                                                  |
| ------------ | ------------------------------------------------------------ |
| `jq`         | Used to parse the output of `lm-sensors` for a specific sensor value. |
| `lm-sensors` | Used to collect data on sensors.                             |
| `ipmitool`   | Used to get and set fan duty cycle configurations.           |

<hr>

## Configuration

| Variable                       | Description                                                  |
| ------------------------------ | ------------------------------------------------------------ |
| `SLEEP_INTERVAL`               | The amount of time to sleep between script executions.       |
| `SENSOR_JSONPATH`              | The JSONPath for the sensor to monitor.                      |
| `CPU_TCASE`                    | The maximum operating temperature of the CPU. Usually found in the product specifications. |
| `CPU_THRESHOLD_TEMP`           | The threshold temperature where the fan curve should be overriden and set to `CPU_THRESHOLD_DUTY_CYCLE`. |
| `CPU_THRESHOLD_DUTY_CYCLE`     | The duty cycle to use when the current CPU temperature exceeds the `CPU_THRESHOLD_TEMP`. |
| `FAN_LOWER_CRITICAL_THRESHOLD` | The lowest Lower Critical value of fans in the system pool.  |

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
