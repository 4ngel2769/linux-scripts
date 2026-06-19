#!/bin/bash
# Custom mode: powersave1
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
echo 'power' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
sudo envycontrol -s 
echo 1 | sudo tee /sys/devices/system/cpu/cpu1/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu2/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu3/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu4/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu5/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu6/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu7/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu8/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu9/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu10/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu11/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu12/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu13/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu14/online > /dev/null
echo 1 | sudo tee /sys/devices/system/cpu/cpu15/online > /dev/null
