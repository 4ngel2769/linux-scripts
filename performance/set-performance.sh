#!/bin/bash
# Performance Mode
echo "Setting Performance Mode..."
# Enable Turbo
echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
# Online all cores (P-cores 0-7, E-cores 8-15)
for i in {0..15}; do echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online; done
# EPP
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
# GPU Profile
sudo envycontrol -s nvidia
echo "Performance mode set. Note: GPU change may require restart."
