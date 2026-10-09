#!/bin/bash
# Exercises fancontrol's curves and failure handling with sensors and ipmitool stubbed out,
# so it runs anywhere with bash and jq and never touches a real BMC or GPU.

TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FIXTURE="$TEST_DIR/fixtures/sensors-idle.json"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
IPMI_LOG="$WORK_DIR/ipmitool.log"
OUT="$WORK_DIR/out.log"

# shellcheck source=SCRIPTDIR/../fancontrol
source "$TEST_DIR/../fancontrol"

sensors() {
    [[ $FAKE_SENSORS_RC -eq 0 ]] || return "$FAKE_SENSORS_RC"
    printf '%s\n' "$FAKE_SENSORS_JSON"
}

ipmitool() {
    echo "$*" >> "$IPMI_LOG"
    case "$*" in
        "raw 0x30 0x45 0x01 0x01") return "$FAKE_MODE_RC" ;;
        "raw 0x30 0x70 0x66 0x00 "*)
            [[ $FAKE_READ_RC -eq 0 ]] || return "$FAKE_READ_RC"
            echo " 35" ;;
        "raw 0x30 0x70 0x66 0x01 "*) return "$FAKE_SET_RC" ;;
    esac
}

date() { echo "Thu Oct  8 23:00:00 PDT 2026"; }

passed=0
failed=0

pass() { passed=$((passed + 1)); echo "  ok   - $1"; }
fail() { failed=$((failed + 1)); echo "  FAIL - $1"; [[ -n "$2" ]] && echo "         $2"; }

assert_eq() {
    local name=$1 expected=$2 actual=$3
    if [[ "$expected" == "$actual" ]]; then pass "$name"; else fail "$name" "expected '$expected', got '$actual'"; fi
}

assert_log() {
    local name=$1 pattern=$2
    if grep -qF -- "$pattern" "$OUT"; then pass "$name"; else fail "$name" "missing '$pattern' in: $(tr '\n' '|' < "$OUT")"; fi
}

assert_no_log() {
    local name=$1 pattern=$2
    if grep -qF -- "$pattern" "$OUT"; then fail "$name" "unexpected '$pattern'"; else pass "$name"; fi
}

reset_state() {
    local var
    for var in $(compgen -v last_warn_); do unset "$var"; done
    FAKE_SENSORS_RC=0 FAKE_MODE_RC=0 FAKE_READ_RC=0 FAKE_SET_RC=0
    unset fan_mode_set
    : > "$IPMI_LOG"
}

# Builds sensors JSON from the real host capture. A value of "absent" deletes the reading,
# "nochip" deletes the whole sensor chip, anything else is injected verbatim as JSON.
set_sensors() {
    local cpu=$1 gpu=$2 filter='.'
    case "$cpu" in
        absent) filter+=' | del(.["coretemp-isa-0000"]["Package id 0"].temp1_input)' ;;
        nochip) filter+=' | del(.["coretemp-isa-0000"])' ;;
        *)      filter+=" | .[\"coretemp-isa-0000\"][\"Package id 0\"].temp1_input = $cpu" ;;
    esac
    case "$gpu" in
        absent) filter+=' | del(.["amdgpu-pci-0500"].junction.temp2_input)' ;;
        nochip) filter+=' | del(.["amdgpu-pci-0500"])' ;;
        *)      filter+=" | .[\"amdgpu-pci-0500\"].junction.temp2_input = $gpu" ;;
    esac
    FAKE_SENSORS_JSON=$(command jq "$filter" "$FIXTURE")
}

poll() {
    : > "$IPMI_LOG"
    { calculate_duty_cycle; set_duty_cycle; } > "$OUT" 2>&1
}

# Both zones must have been sent the same duty, and nothing else written
written_duty() {
    local zone0 zone1
    zone0=$(grep '^raw 0x30 0x70 0x66 0x01 0x00 ' "$IPMI_LOG" | awk '{print $7}')
    zone1=$(grep '^raw 0x30 0x70 0x66 0x01 0x01 ' "$IPMI_LOG" | awk '{print $7}')
    if [[ "$zone0" == "$zone1" ]]; then echo "${zone0#0x}"; else echo "zones differ: $zone0 $zone1"; fi
}

echo "GPU curve points"
for case in 20:0 38:0 64:0 65:24 70:28 75:32 80:38 85:44 88:56 90:64 95:64 115:64; do
    assert_eq "hotspot ${case%%:*}°C requests ${case##*:}/64" "${case##*:}" "$(gpu_curve_duty "${case%%:*}")"
done

echo "Real idle capture from earth (CPU 45°C, GPU 37°C)"
reset_state; FAKE_SENSORS_JSON=$(cat "$FIXTURE"); poll
assert_eq "CPU duty from existing curve" 35 "$cpu_duty_cycle"
assert_eq "idle GPU adds no demand" 0 "$gpu_duty_cycle"
assert_eq "writes CPU duty to both zones" 35 "$(written_duty)"
assert_log "log shows GPU hotspot" "GPU hotspot:         37°C"
assert_log "log shows source" "Setting duty cycle:  35/64 (cpu curve)"

echo "GPU curve end-to-end with a cool CPU (25°C, below LC minimum)"
for case in 38:20 65:24 75:32 85:44 90:64 95:64; do
    reset_state; set_sensors 25 "${case%%:*}"; poll
    assert_eq "hotspot ${case%%:*}°C applies ${case##*:}/64" "${case##*:}" "$(written_duty)"
done
reset_state; set_sensors 25 38; poll
assert_log "idle GPU falls back to LC minimum" "(LC minimum)"

echo "max(cpu, gpu)"
reset_state; set_sensors 55 70; poll
assert_eq "CPU 55°C (44) beats GPU 70°C (28)" 44 "$(written_duty)"
assert_log "source is CPU" "(cpu curve)"
reset_state; set_sensors 45 85; poll
assert_eq "GPU 85°C (44) beats CPU 45°C (35)" 44 "$(written_duty)"
assert_log "source is GPU" "(gpu curve)"
reset_state; set_sensors 60 70; poll
assert_eq "GPU demand never lowers CPU demand (CPU 60°C = 48)" 48 "$(written_duty)"

echo "CPU threshold override"
reset_state; set_sensors 66 38; poll
assert_eq "CPU 66°C forces 64" 64 "$(written_duty)"
assert_log "override is labelled" "OVERRIDE: CPU above threshold"
reset_state; set_sensors 65 38; poll
assert_eq "CPU exactly 65°C stays on curve (unchanged boundary)" 52 "$(written_duty)"
reset_state; set_sensors 66 95; poll
assert_eq "CPU override still 64 with hot GPU" 64 "$(written_duty)"

echo "GPU offline (junction reading absent)"
for gpu in absent nochip; do
    reset_state; set_sensors 45 "$gpu"; poll
    assert_eq "$gpu: no GPU demand" 0 "$gpu_duty_cycle"
    assert_eq "$gpu: CPU curve applied" 35 "$(written_duty)"
    assert_log "$gpu: logged as offline" "GPU hotspot:         offline"
    assert_log "$gpu: warns" "WARN - GPU hotspot not reported"
done
reset_state; set_sensors 45 absent; poll; poll
assert_no_log "offline warning not repeated next poll" "WARN - GPU hotspot not reported"
SECONDS=$((SECONDS + WARN_REPEAT_INTERVAL)); poll
assert_log "offline warning repeats after interval" "WARN - GPU hotspot not reported"
set_sensors 45 37; poll
assert_log "recovery is logged" "INFO - GPU hotspot reading restored"
poll
assert_no_log "recovery logged only once" "restored"

echo "GPU telemetry faults"
for gpu in '"abc"' '""' 0 -5 5 200 '"9e9"' '{}' '[]' 'true'; do
    reset_state; set_sensors 45 "$gpu"; poll
    assert_eq "GPU reading $gpu forces 64" 64 "$(written_duty)"
    assert_log "GPU reading $gpu labelled" "OVERRIDE: GPU telemetry fault"
done
reset_state; set_sensors 45 '"abc"'; poll; poll
assert_no_log "fault warning rate-limited" "WARN - Invalid GPU hotspot"
assert_eq "fault still forces 64 while warning is suppressed" 64 "$(written_duty)"

echo "CPU telemetry faults keep the existing conservative fallback"
for cpu in absent nochip '"abc"' 0 200; do
    reset_state; set_sensors "$cpu" 37; poll
    assert_eq "CPU reading $cpu assumes Tcase and forces 64" 64 "$(written_duty)"
    assert_log "CPU reading $cpu warns" "Failed to read CPU temp"
done

echo "sensors command failures"
reset_state; FAKE_SENSORS_RC=1; poll
assert_eq "sensors exits non-zero with no output: 64" 64 "$(written_duty)"
reset_state; FAKE_SENSORS_JSON='{"coretemp-isa-0000": {'; poll
assert_eq "truncated JSON: 64" 64 "$(written_duty)"
reset_state; FAKE_SENSORS_JSON=''; poll
assert_eq "empty output: 64" 64 "$(written_duty)"

echo "BMC failures"
reset_state; FAKE_SET_RC=1; set_sensors 45 37; poll
assert_log "zone 0 failure reported" "ERROR - BMC rejected duty cycle 35/64 for fan zone 0x00"
assert_log "zone 1 failure reported" "ERROR - BMC rejected duty cycle 35/64 for fan zone 0x01"
poll
assert_no_log "BMC error rate-limited" "ERROR - BMC rejected"
FAKE_SET_RC=0; poll
assert_log "BMC recovery logged" "BMC accepted duty cycle for fan zone 0x00 again"
reset_state; FAKE_READ_RC=1; set_sensors 45 37; poll
assert_log "unreadable current duty shown as unknown" "Current duty cycle:  unknown/64"
assert_eq "still applies duty when readback fails" 35 "$(written_duty)"
reset_state; FAKE_MODE_RC=1; set_fan_mode > "$OUT"
assert_log "fan mode failure reported" "ERROR - Failed to set fan control mode"
assert_eq "fan mode not marked as set" "" "$fan_mode_set"
FAKE_MODE_RC=0; set_fan_mode > "$OUT"
assert_eq "fan mode set on retry" true "$fan_mode_set"

echo "Sweep: every CPU/GPU combination writes a valid, monotonic duty"
sweep_errors=0
for cpu in 20 30 40 50 60 64 65 66 70 79 90; do
    previous=0
    for gpu in $(seq 15 120); do
        reset_state; set_sensors "$cpu" "$gpu"; poll
        duty=$(written_duty)
        if ! [[ "$duty" =~ ^[0-9]+$ ]] || (( duty < 20 || duty > 64 || duty < previous )); then
            sweep_errors=$((sweep_errors + 1))
            echo "         cpu=$cpu gpu=$gpu duty=$duty previous=$previous"
        fi
        previous=$duty
    done
done
assert_eq "sweep found no invalid or decreasing duties" 0 "$sweep_errors"

echo
echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
