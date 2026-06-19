#!/bin/bash
# Power Saving Mode
echo "Setting Power Saving Mode..."
# Disable Turbo
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
# Offline E-cores (8-15) to save power, keep P-cores online
for i in {8..15}; do echo 0 | sudo tee /sys/devices/system/cpu/cpu$i/online; done
# EPP
echo "power" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
# GPU Profile
sudo envycontrol -s integrated
echo "Power saving mode set. Note: GPU change may require restart."
