#!/bin/bash

# Maximum Operating Temperatures (Celsius)
TEMP_MAX_CPU=79
SLEEP_CYCLE=.1

set_duty_cycle() {
    cpu_temp=$(sensors -j | jq '.["coretemp-isa-0000"]["Package id 0"].temp1_input')
    cpu_percent=$(( (cpu_temp * 100) / TEMP_MAX_CPU ))
    duty_cycle_percent=$(( (cpu_percent * 64) / 100 ))

    echo "Current Temp: $cpu_temp/$TEMP_MAX_CPU"
    echo "Percentage of Max: $cpu_percent%"
    echo "Setting duty cycle to: $duty_cycle_percent/64"

    ipmitool raw 0x30 0x70 0x66 0x01 0x00 "$duty_cycle_percent"
}

main() {
    ipmitool raw 0x30 0x45 0x01 0x01

    while true; do
        set_duty_cycle
        sleep $SLEEP_CYCLE
    done
}

main "$@"
