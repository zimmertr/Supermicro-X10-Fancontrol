# Supermicro X10 Fancontrol

## Summary

This script is used to dynamically control the fan duty cycle (speed) on a Supermicro X10 server by calculating the current percentage of the maximum operating temperature of a CPU and setting the duty cycle of the fans to the equivalent percentage of their maximum speed. 

For example, if your CPU's maximum operating temperature is 79°C, and the current sensor reading is 40°C, it is at ~51% of the maximum. The fan speeds will then be set to 51% accordingly. If the current CPU temperature exceeds the desired CPU threshold temperature, the CPU threshold duty cycle will be used instead. If the desired duty cycle results in a lower RPM than the Lower Critical threshold of the fans in the pool, the Lower Critical treshold will be used as the duty cycle instead.

To find the maximum operating temperature and the ideal threshold temperature of a CPU, consult it's production specifications. To find the Lower Critical threshold of the fans, use `ipmitool sensor | grep FAN` and review the values in the 6th column. To the find correlated duty cycle value, use `ipmitool raw 0x30 0x70 0x66 0x01 0x00 0x##` with progressively lower integers until the set duty cycle drops the fan RPMs below the Lower Critical threshold and the BMC overrides the configuration. If you wish, you can customize these thresholds to set a lower or higher value with `ipmitool sensor thresh "FAN#" lower ### ### ###`. I use `100 300 500` with a pool of Noctua A12x25 fans and my server is virtually silent. 

An AMD GPU's hotspot (junction) temperature is a second input. It has its own curve, `GPU_CURVE`, a list of `temp:duty` points with straight-line interpolation between them. The script sends whichever is higher, the CPU's duty or the GPU's, so GPU heat can only add airflow, never remove it. The GPU reading comes from the same `sensors -j` call as the CPU and needs no extra packages. When the GPU powers down at idle, `sensors` stops reporting its temperature. The script treats that as "nothing to cool", adds no GPU demand, and logs a warning at most every `WARN_REPEAT_INTERVAL` seconds. A reading that is present but not a plausible number (text, out of range) counts as a fault and runs the fans at `GPU_FAULT_DUTY_CYCLE`.

The BMC reads the duty byte as hex, so the `0-64` scale used throughout is really `0x00-0x64`, i.e. 0-100%. `20` is 32% and `64` is 100%. Higher numbers are always faster, but the steps are uneven: each step within a decade is 1%, and crossing one (29 to 30) is 7%.

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
| `FAN_MAX_DUTY_CYCLE`           | The highest duty cycle ever sent to the BMC (`64` = 0x64 = 100%). |
| `GPU_SENSOR_JSONPATH`          | The JSONPath for the GPU hotspot sensor. `amdgpu-pci-0500` comes from the GPU's PCI address (`0000:05:00.0`). |
| `GPU_CURVE`                    | Space-separated `temp:duty` points for the GPU hotspot curve, in ascending order. Below the first point the GPU adds no demand. |
| `GPU_FAULT_DUTY_CYCLE`         | The duty cycle to use when the GPU reports an implausible reading. |
| `TEMP_MIN_VALID` / `TEMP_MAX_VALID` | Readings outside this range are treated as sensor faults. |
| `WARN_REPEAT_INTERVAL`         | Seconds before a persistent warning is logged again.         |

<hr>

## Installation

```bash
cp fancontrol /usr/bin/fancontrol
chmod +x /usr/bin/fancontrol
cp fancontrol.service /etc/systemd/system/fancontrol.service
systemctl enable --now fancontrol
```

<hr>

## Testing

The tests stub out `sensors` and `ipmitool`, so they run anywhere with `bash` and `jq` and never touch a real BMC or GPU.

```bash
bash tests/test_fancontrol.sh
```

<hr>

## Example Output

Idle, sustained GPU load, then the GPU powering down. Built from the test fixture rather than a live capture.

```bash
$> journalctl -xefu fancontrol

Oct 08 23:03:22 earth fancontrol[181096]: -----Thu Oct  8 23:03:22 PDT 2026-----
Oct 08 23:03:22 earth fancontrol[181096]: INFO - CPU temperature:     45/79°C (56%)
Oct 08 23:03:22 earth fancontrol[181096]: INFO - GPU hotspot:         37°C
Oct 08 23:03:22 earth fancontrol[181096]: INFO - CPU requested duty:  35/64
Oct 08 23:03:22 earth fancontrol[181096]: INFO - GPU requested duty:  0/64
Oct 08 23:03:22 earth fancontrol[181096]: INFO - Current duty cycle:  35/64
Oct 08 23:03:22 earth fancontrol[181096]: INFO - Setting duty cycle:  35/64 (cpu curve)
Oct 08 23:05:20 earth fancontrol[181096]: -----Thu Oct  8 23:05:20 PDT 2026-----
Oct 08 23:05:20 earth fancontrol[181096]: INFO - CPU temperature:     46/79°C (58%)
Oct 08 23:05:20 earth fancontrol[181096]: INFO - GPU hotspot:         95°C
Oct 08 23:05:20 earth fancontrol[181096]: INFO - CPU requested duty:  37/64
Oct 08 23:05:20 earth fancontrol[181096]: INFO - GPU requested duty:  64/64
Oct 08 23:05:20 earth fancontrol[181096]: INFO - Current duty cycle:  37/64
Oct 08 23:05:20 earth fancontrol[181096]: INFO - Setting duty cycle:  64/64 (gpu curve)
Oct 08 23:12:41 earth fancontrol[181096]: -----Thu Oct  8 23:12:41 PDT 2026-----
Oct 08 23:12:41 earth fancontrol[181096]: WARN - GPU hotspot not reported (GPU suspended?), no GPU fan demand
Oct 08 23:12:41 earth fancontrol[181096]: INFO - CPU temperature:     45/79°C (56%)
Oct 08 23:12:41 earth fancontrol[181096]: INFO - GPU hotspot:         offline
Oct 08 23:12:41 earth fancontrol[181096]: INFO - CPU requested duty:  35/64
Oct 08 23:12:41 earth fancontrol[181096]: INFO - GPU requested duty:  0/64
Oct 08 23:12:41 earth fancontrol[181096]: INFO - Current duty cycle:  64/64
Oct 08 23:12:41 earth fancontrol[181096]: INFO - Setting duty cycle:  35/64 (cpu curve)
```

Safety overrides show up in the `Setting duty cycle` line as `OVERRIDE: CPU above threshold` or `OVERRIDE: GPU telemetry fault`.
