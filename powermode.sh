#!/bin/bash

# Main Power Management Script
# Usage: ./powermode.sh [saving|default|performance|info|save|apply|list|remove|help]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CUSTOM_DIR="$SCRIPT_DIR/custom"
mkdir -p "$CUSTOM_DIR"

# Ensure envycontrol is installed
check_dependencies() {
    if ! command -v envycontrol &> /dev/null; then
        echo "envycontrol is not installed."
        read -p "Would you like to install it now? (y/n): " choice
        case "$choice" in
            y|Y)
                echo "Installing envycontrol for Fedora..."
                sudo dnf copr enable sunwire/envycontrol -y
                sudo dnf install python3-envycontrol -y
                ;;
            *)
                echo "envycontrol is required for GPU switching."
                exit 1
                ;;
        esac
    fi
}

# Run dependency check
check_dependencies

help() {
    echo "Usage: $0 {saving|default|performance|info|save <name>|apply <name>|list|remove <name>|help}"
    echo
    echo "Standard Commands:"
    echo "  saving       Enable Power Saving mode"
    echo "  default      Enable Default mode"
    echo "  performance  Enable Performance mode"
    echo "  info         Display current power configuration"
    echo
    echo "Custom Commands:"
    echo "  save <name>  Capture current configuration to a custom mode"
    echo "  apply <name> Apply a saved custom mode"
    echo "  list         List saved custom modes"
    echo "  remove <name> Delete a custom mode"
}

# Function to apply EPP to all online cores
apply_epp() {
    local epp_value=$1
    for i in $(cat /sys/devices/system/cpu/online | tr ',' ' ' | xargs -n1 bash -c 'eval echo $0' | sort -n); do
        echo "$epp_value" | sudo tee "/sys/devices/system/cpu/cpu$i/cpufreq/energy_performance_preference" > /dev/null
    done
}

set_mode() {
    local mode=$1
    echo "Setting $mode mode..."
    
    case $mode in
        saving)
            # Disable Turbo
            echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
            
            # Offline E-cores (8-15) - Do this BEFORE setting EPP to avoid applying it to offline cores
            for i in {8..15}; do echo 0 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null; done
            
            # Apply EPP to remaining online cores
            apply_epp "power"
            
            # GPU Profile
            sudo envycontrol -s integrated
            ;;
        default)
            # Enable Turbo
            echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
            
            # Online all cores (0-15)
            for i in {0..15}; do echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null; done
            
            # Apply EPP to all cores
            apply_epp "balance_performance"
            
            # GPU Profile
            sudo envycontrol -s hybrid
            ;;
        performance)
            # Enable Turbo
            echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
            
            # Online all cores (0-15)
            for i in {0..15}; do echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null; done
            
            # Apply EPP to all cores
            apply_epp "performance"
            
            # GPU Profile
            sudo envycontrol -s nvidia
            ;;
    esac
    echo "Done."
}

show_info() {
    echo "--- Current Power Configuration ---"
    echo -n "Turbo: "
    if [ "$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)" -eq 0 ]; then echo "Enabled"; else echo "Disabled"; fi
    echo -n "GPU Profile: "
    envycontrol -q
    echo -n "EPP Preference: "
    cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
    echo -n "Cores Online: "
    cat /sys/devices/system/cpu/online
}

save_mode() {
    local name=$1
    if [ -z "$name" ]; then echo "Error: Name required"; return; fi
    local script="$CUSTOM_DIR/$name.sh"
    echo "#!/bin/bash" > "$script"
    echo "# Custom mode: $name" >> "$script"
    echo "echo $(cat /sys/devices/system/cpu/intel_pstate/no_turbo) | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null" >> "$script"
    # Set EPP first
    echo "echo '$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null" >> "$script"
    
    # Correctly capture the GPU mode. `envycontrol -q` output format depends on version, assuming "GPU mode: <mode>"
    local gpu_mode=$(envycontrol -q | awk -F': ' '{print $2}')
    echo "sudo envycontrol -s $gpu_mode" >> "$script"
    
    # Online cores - skip cpu0 as it cannot be toggled
    for i in {1..15}; do
        if [ -f "/sys/devices/system/cpu/cpu$i/online" ]; then
            state=$(cat "/sys/devices/system/cpu/cpu$i/online")
            echo "echo $state | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null" >> "$script"
        fi
    done
    chmod +x "$script"
    echo "Mode '$name' saved to $script."
}

list_modes() {
    echo "--- Saved Custom Modes ---"
    ls -1 "$CUSTOM_DIR" | sed 's/\.sh$//'
}

case "$1" in
    saving|default|performance)
        set_mode "$1"
        ;;
    info)
        show_info
        ;;
    save)
        save_mode "$2"
        ;;
    apply)
        if [ -f "$CUSTOM_DIR/$2.sh" ]; then
            sudo "$CUSTOM_DIR/$2.sh"
        else
            echo "Error: Mode '$2' not found."
        fi
        ;;
    list)
        list_modes
        ;;
    remove)
        if [ -f "$CUSTOM_DIR/$2.sh" ]; then
            rm "$CUSTOM_DIR/$2.sh"
            echo "Mode '$2' removed."
        else
            echo "Error: Mode '$2' not found."
        fi
        ;;
    help|*)
        help
        ;;
esac
