#!/bin/bash

# Main Power Management Script
# Usage: ./powermode.sh [saving|default|performance|info|save|apply|list|remove|tui|help]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CUSTOM_DIR="$SCRIPT_DIR/custom"
mkdir -p "$CUSTOM_DIR"

# ---------------------------------------------------------------------------
# Dependency detection & auto-installation
# ---------------------------------------------------------------------------

detect_distro() {
    local id=""
    local id_like=""

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        id="$ID"
        id_like="$ID_LIKE"
    fi

    case "$id" in
        fedora)            echo "fedora" ;;
        rhel|centos)       echo "rhel" ;;
        debian)            echo "debian" ;;
        ubuntu|pop|linuxmint|elementary|zorin) echo "ubuntu" ;;
        arch|manjaro|endeavouros|artix|arcolinux) echo "arch" ;;
        opensuse*|suse|sles) echo "opensuse" ;;
        alpine)            echo "alpine" ;;
        void)              echo "void" ;;
        gentoo)            echo "gentoo" ;;
        nixos)             echo "nixos" ;;
        *)
            if echo "$id_like" | grep -qi "fedora\|rhel"; then
                echo "fedora"
            elif echo "$id_like" | grep -qi "debian\|ubuntu"; then
                echo "debian"
            elif echo "$id_like" | grep -qi "arch"; then
                echo "arch"
            elif echo "$id_like" | grep -qi "suse"; then
                echo "opensuse"
            else
                for pm in apt dnf pacman zypper apk emerge xbps-install nix-env; do
                    if command -v "$pm" &>/dev/null; then
                        case "$pm" in
                            apt) echo "debian"; return ;;
                            dnf) echo "fedora"; return ;;
                            pacman) echo "arch"; return ;;
                            zypper) echo "opensuse"; return ;;
                            apk) echo "alpine"; return ;;
                            emerge) echo "gentoo"; return ;;
                            xbps-install) echo "void"; return ;;
                            nix-env) echo "nixos"; return ;;
                        esac
                    fi
                done
                echo "unknown"
            fi
            ;;
    esac
}

distro_pm() {
    case "$(detect_distro)" in
        fedora|rhel)    echo "dnf" ;;
        debian|ubuntu)  echo "apt" ;;
        arch)           echo "pacman" ;;
        opensuse)       echo "zypper" ;;
        alpine)         echo "apk" ;;
        gentoo)         echo "emerge" ;;
        void)           echo "xbps-install" ;;
        nixos)          echo "nix-env" ;;
        *)              echo "" ;;
    esac
}

distro_pm_install() {
    case "$(detect_distro)" in
        fedora|rhel)    echo "sudo dnf install -y" ;;
        debian|ubuntu)  echo "sudo apt install -y" ;;
        arch)           echo "sudo pacman -S --noconfirm" ;;
        opensuse)       echo "sudo zypper install -y" ;;
        alpine)         echo "sudo apk add" ;;
        gentoo)         echo "sudo emerge --ask=n" ;;
        void)           echo "sudo xbps-install -y" ;;
        nixos)          echo "nix-env -iA nixos." ;;
        *)              echo "" ;;
    esac
}

distro_pm_update() {
    case "$(detect_distro)" in
        fedora|rhel)    echo "sudo dnf check-update -y &>/dev/null || true" ;;
        debian|ubuntu)  echo "sudo apt update -y" ;;
        arch)           echo "sudo pacman -Sy" ;;
        opensuse)       echo "sudo zypper refresh" ;;
        alpine)         echo "sudo apk update" ;;
        gentoo)         echo "sudo emerge --sync" ;;
        void)           echo "sudo xbps-install -S" ;;
        *)              echo ":" ;;
    esac
}

distro_name() {
    case "$(detect_distro)" in
        fedora)     echo "Fedora" ;;
        rhel)       echo "RHEL/CentOS" ;;
        debian)     echo "Debian" ;;
        ubuntu)     echo "Ubuntu" ;;
        arch)       echo "Arch Linux" ;;
        opensuse)   echo "openSUSE" ;;
        alpine)     echo "Alpine Linux" ;;
        gentoo)     echo "Gentoo" ;;
        void)       echo "Void Linux" ;;
        nixos)      echo "NixOS" ;;
        *)          echo "unknown" ;;
    esac
}

install_native_packages() {
    local pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    local pm_install
    pm_install=$(distro_pm_install)
    if [[ -z "$pm_install" ]]; then
        return 1
    fi

    local pm_update
    pm_update=$(distro_pm_update)

    echo "Updating package cache..."
    eval "$pm_update"
    echo "Installing: ${pkgs[*]}"
    $pm_install "${pkgs[@]}"
}

install_envycontrol() {
    local distro
    distro=$(detect_distro)

    case "$distro" in
        fedora|rhel)
            echo "Enabling COPR repository for envycontrol..."
            sudo dnf copr enable sunwire/envycontrol -y || true
            install_native_packages python3-envycontrol
            return $?
            ;;
        arch)
            echo "envycontrol is available in AUR."
            if command -v yay &>/dev/null; then
                yay -S --noconfirm envycontrol
                return $?
            elif command -v paru &>/dev/null; then
                paru -S --noconfirm envycontrol
                return $?
            fi
            echo "Install yay/paru first, then run: yay -S envycontrol"
            echo "Falling back to pip..."
            ;;
    esac

    install_native_packages python3-envycontrol 2>/dev/null
    if command -v envycontrol &>/dev/null; then
        return 0
    fi

    if command -v pip3 &>/dev/null; then
        echo "Installing envycontrol via pip..."
        pip3 install --user envycontrol 2>/dev/null || sudo pip3 install envycontrol
        return $?
    fi

    echo "pip3 not found. Install Python pip and run: pip3 install --user envycontrol"
    return 1
}

check_dependencies() {
    local missing_pkg=()
    local missing_name=()

    if ! command -v envycontrol &>/dev/null; then
        missing_pkg+=("envycontrol")
        missing_name+=("envycontrol (GPU switching)")
    fi

    if [[ ${#missing_pkg[@]} -eq 0 ]]; then
        return 0
    fi

    local distro
    distro=$(detect_distro)
    echo "Detected distribution: $(distro_name)"
    echo ""
    echo "Missing dependencies:"
    for name in "${missing_name[@]}"; do
        echo "  - $name"
    done
    echo ""
    read -p "Install missing dependencies? (y/N): " choice

    if [[ "$choice" =~ ^[yY] ]]; then
        local failed=()
        for pkg in "${missing_pkg[@]}"; do
            echo "--- Installing $pkg ---"
            case "$pkg" in
                envycontrol) install_envycontrol ;;
            esac
            if [[ $? -ne 0 ]]; then
                failed+=("$pkg")
            fi
        done

        if [[ ${#failed[@]} -gt 0 ]]; then
            echo "Failed to install: ${failed[*]}"
            echo "You can retry with: ./powermode.sh --install-deps"
            exit 1
        else
            echo "All dependencies installed successfully."
        fi
    else
        echo "Dependencies missing. Some features may not work."
        echo "Run './powermode.sh --install-deps' to install them later."
        if [[ "$1" == "--require-all" ]]; then
            exit 1
        fi
    fi
}

install_all_deps() {
    local distro
    distro=$(detect_distro)
    echo "Distribution: $(distro_name)"
    echo ""

    install_envycontrol

    echo ""
    echo "Verifying installation..."
    if command -v envycontrol &>/dev/null; then
        echo "All dependencies ready."
    else
        echo "envycontrol: NOT FOUND"
    fi
}

# Run dependency check on startup (non-fatal for most commands)
check_dependencies

help() {
    cat <<EOF
Usage: $0 {saving|default|performance|info|save <name>|apply <name>|list|remove <name>|tui|help}

Standard Commands:
  saving       Enable Power Saving mode
  default      Enable Default mode
  performance  Enable Performance mode
  info         Display current power configuration

Custom Commands:
  save <name>  Capture current configuration to a custom mode
  apply <name> Apply a saved custom mode
  list         List saved custom modes
  remove <name> Delete a custom mode

Interactive:
  tui          Open interactive TUI to manually configure
               turbo boost, CPU cores, EPP, and GPU mode

EOF
}

expand_cpu_range() {
    local range="$1"
    local parts expanded=()

    if [[ -z "$range" ]]; then
        return
    fi

    IFS=',' read -ra parts <<< "$range"
    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start=${BASH_REMATCH[1]}
            local end=${BASH_REMATCH[2]}
            if [[ $start -le $end ]]; then
                for ((i = start; i <= end; i++)); do
                    expanded+=("$i")
                done
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            expanded+=("$part")
        fi
    done

    echo "${expanded[@]}"
}

detect_online_cpus() {
    local range
    range=$(cat /sys/devices/system/cpu/online 2>/dev/null) || return 1
    expand_cpu_range "$range"
}

detect_all_cpus() {
    ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | sed 's/.*cpu//' | sort -n
}

detect_core_type() {
    local cpu=$1

    local siblings_file="/sys/devices/system/cpu/cpu${cpu}/topology/thread_siblings_list"
    if [[ -f "$siblings_file" ]]; then
        local siblings count
        siblings=$(expand_cpu_range "$(tr -d ' ' < "$siblings_file")")
        count=$(echo "$siblings" | wc -w)
        if [[ $count -gt 1 ]]; then
            echo "P-core"
            return
        fi
    fi

    local core_type_file="/sys/devices/system/cpu/cpu${cpu}/topology/core_type"
    if [[ -f "$core_type_file" ]]; then
        local val
        val=$(cat "$core_type_file")
        case "$val" in
            1|0x20|32) echo "E-core"; return ;;
            2|0x40|64) echo "P-core"; return ;;
        esac
    fi

    echo "E-core"
}

read_turbo() {
    local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"
    if [[ -f "$turbo_file" ]]; then
        cat "$turbo_file"
    elif [[ -d "/sys/devices/system/cpu/cpufreq" ]]; then
        echo "N/A"
    else
        echo "N/A"
    fi
}

read_epp() {
    local epp_file="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
    if [[ -f "$epp_file" ]]; then
        cat "$epp_file"
    else
        echo "N/A"
    fi
}

read_gpu_mode() {
    envycontrol -q 2>/dev/null || echo "unknown"
}

apply_epp() {
    local epp_value=$1
    local cpus
    cpus=$(detect_online_cpus) || { echo "Warning: no online CPUs found"; return 1; }

    for i in $cpus; do
        local target="/sys/devices/system/cpu/cpu${i}/cpufreq/energy_performance_preference"
        if [[ -f "$target" ]]; then
            echo "$epp_value" | sudo tee "$target" > /dev/null
        fi
    done
}

set_mode() {
    local mode=$1
    echo "Setting $mode mode..."

    case $mode in
        saving)
            echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
            for i in $(detect_all_cpus); do
                local type
                type=$(detect_core_type "$i")
                local online_file="/sys/devices/system/cpu/cpu${i}/online"
                if [[ "$type" == "E-core" && -f "$online_file" ]]; then
                    echo 0 | sudo tee "$online_file" > /dev/null
                fi
            done
            apply_epp "power"
            sudo envycontrol -s integrated
            ;;
        default)
            echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
            for i in $(detect_all_cpus); do
                local online_file="/sys/devices/system/cpu/cpu${i}/online"
                [[ -f "$online_file" ]] && echo 1 | sudo tee "$online_file" > /dev/null
            done
            apply_epp "balance_performance"
            sudo envycontrol -s hybrid
            ;;
        performance)
            echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
            for i in $(detect_all_cpus); do
                local online_file="/sys/devices/system/cpu/cpu${i}/online"
                [[ -f "$online_file" ]] && echo 1 | sudo tee "$online_file" > /dev/null
            done
            apply_epp "performance"
            sudo envycontrol -s nvidia
            ;;
    esac
    echo "Done."
}

show_info() {
    local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"

    echo "--- Current Power Configuration ---"
    printf "Turbo: "
    if [[ -f "$turbo_file" ]]; then
        if [[ $(cat "$turbo_file") == 0 ]]; then echo "Enabled"; else echo "Disabled"; fi
    else
        echo "N/A (intel_pstate not available)"
    fi
    printf "GPU Profile: "
    envycontrol -q 2>/dev/null || echo "N/A"
    printf "EPP Preference: "
    read_epp
    printf "Cores Online: "
    cat /sys/devices/system/cpu/online 2>/dev/null || echo "N/A"
}

validate_name() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

save_mode() {
    local name=$1
    if [[ -z "$name" ]]; then echo "Error: Name required"; return 1; fi
    if ! validate_name "$name"; then echo "Error: Name must be alphanumeric (dashes/underscores allowed)"; return 1; fi

    local script="$CUSTOM_DIR/$name.sh"

    echo "#!/bin/bash" > "$script"
    echo "# Custom mode: $name" >> "$script"

    local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"
    if [[ -f "$turbo_file" ]]; then
        echo "echo $(cat "$turbo_file") | sudo tee $turbo_file > /dev/null" >> "$script"
    fi

    local epp
    epp=$(read_epp)
    if [[ "$epp" != "N/A" ]]; then
        echo "echo '$epp' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null" >> "$script"
    fi

    local gpu_mode
    gpu_mode=$(envycontrol -q 2>/dev/null)
    if [[ -n "$gpu_mode" ]]; then
        local parsed_gpu
        parsed_gpu=$(echo "$gpu_mode" | grep -oiP '(integrated|hybrid|nvidia)' | head -1)
        if [[ -n "$parsed_gpu" ]]; then
            echo "sudo envycontrol -s $parsed_gpu" >> "$script"
        else
            echo "# GPU mode could not be parsed: $gpu_mode" >> "$script"
        fi
    fi

    for i in $(detect_all_cpus); do
        local online_file="/sys/devices/system/cpu/cpu${i}/online"
        if [[ -f "$online_file" ]]; then
            local state
            state=$(cat "$online_file")
            echo "echo $state | sudo tee $online_file > /dev/null" >> "$script"
        fi
    done

    chmod +x "$script"
    echo "Mode '$name' saved to $script."
}

list_modes() {
    echo "--- Saved Custom Modes ---"
    ls -1 "$CUSTOM_DIR" 2>/dev/null | sed 's/\.sh$//'
}

# ---------------------------------------------------------------------------
# TUI Functions (simple & clean terminal UI)
# ---------------------------------------------------------------------------

if tput setaf 0 &>/dev/null; then
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4)
    C_MAGENTA=$(tput setaf 5)
    C_CYAN=$(tput setaf 6)
    C_WHITE=$(tput setaf 7)
    C_BOLD=$(tput bold)
    C_DIM=$(tput dim)
    C_RESET=$(tput sgr0)
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
    C_MAGENTA=""; C_CYAN=""; C_WHITE=""; C_BOLD=""; C_DIM=""; C_RESET=""
fi

tui_echo() { printf '%b\n' "$*"; }

tui_status_val() {
    local val=$1
    case "$val" in
        0|Enabled|ONLINE|performance|nvidia) printf '%s' "${C_GREEN}${val}${C_RESET}" ;;
        1|Disabled|OFFLINE|power|integrated) printf '%s' "${C_RED}${val}${C_RESET}" ;;
        *)                                   printf '%s' "${C_YELLOW}${val}${C_RESET}" ;;
    esac
}

tui_sep() {
    printf '%s\n' "────────────────────────────────────────────────────"
}

tui_clear() {
    printf '\033[2J\033[H'
}

tui_prompt() {
    printf '%s' "${C_CYAN}${C_BOLD}==>${C_RESET} $1 " >&2
}

tui_ok() {
    printf '%s\n' "${C_GREEN}✓${C_RESET} $1"
}

tui_err() {
    printf '%s\n' "${C_RED}✗${C_RESET} $1"
}

tui_header() {
    local turbo=$1; shift
    local gpu=$1; shift
    local epp=$1; shift
    local cores=$1; shift
    local ncores=$1

    tui_echo ""
    printf '%s\n' "${C_BOLD}${C_CYAN}  Power Mode Manager${C_RESET}"
    tui_sep
    printf '  %-20s %s\n' "${C_DIM}Turbo:${C_RESET}  $(tui_status_val "$turbo")"   "${C_DIM}GPU:${C_RESET}  $(tui_status_val "$gpu")"
    printf '  %-20s %s\n' "${C_DIM}EPP:${C_RESET}   $(tui_status_val "$epp")"     "${C_DIM}Cores:${C_RESET} $(tui_status_val "$cores") (${ncores} online)"
    tui_sep
    tui_echo ""
}

tui_wait() {
    printf '%s' "${C_DIM}Press ENTER to continue...${C_RESET}"
    read -r
}

tui_confirm() {
    local prompt=$1
    local reply
    printf '%s' "${C_YELLOW}${prompt} (y/N) ${C_RESET}"
    read -r reply
    [[ "$reply" =~ ^[yY] ]]
}

tui_read() {
    local prompt=$1
    local var=$2
    local reply
    printf '%s' "${C_CYAN}${C_BOLD}>>${C_RESET} ${prompt}: "
    read -r reply
    eval "$var=\$reply"
}

tui_read_choice() {
    local val
    printf '%s' "${C_CYAN}${C_BOLD}==>${C_RESET} Select option [1-$1]: " >&2
    read -r val
    echo "$val"
}

tui_menu_option() {
    printf '  %s) %s\n' "${C_YELLOW}$1${C_RESET}" "$2"
}

# --- Hybrid CPU Specific ---

tui_hybrid() {
    tui_clear

    local all_cpus
    mapfile -t all_cpus < <(detect_all_cpus)

    local p_cores=() e_cores=() other_cores=()
    for cpu in "${all_cpus[@]}"; do
        local label
        label=$(detect_core_type "$cpu")
        case "$label" in
            P-core) p_cores+=("$cpu") ;;
            E-core) e_cores+=("$cpu") ;;
            *) other_cores+=("$cpu") ;;
        esac
    done

    local turbo_val gpu_val epp_val cores_val
    turbo_val=$(tui_status_val "$(read_turbo)")
    gpu_val=$(read_gpu_mode | grep -oiP '(integrated|hybrid|nvidia)' | head -1)
    epp_val=$(read_epp)
    cores_val=$(cat /sys/devices/system/cpu/online 2>/dev/null || echo "N/A")
    local ncores
    ncores=$(detect_online_cpus | wc -w)
    tui_header "$turbo_val" "$gpu_val" "$epp_val" "$cores_val" "$ncores"

    tui_echo "${C_BOLD}Hybrid CPU Controls:${C_RESET}"
    tui_echo ""
    tui_echo "${C_DIM}P-cores (Performance):${C_RESET} ${p_cores[*]}"
    tui_echo "${C_DIM}E-cores (Efficiency):${C_RESET} ${e_cores[*]}"
    tui_echo ""

    tui_menu_option "1" "Offline all E-cores (Power Saving)"
    tui_menu_option "2" "Online all E-cores (Default/Performance)"
    tui_menu_option "3" "Toggle all E-cores"
    tui_menu_option "4" "Back to main menu"
    tui_echo ""

    local choice
    choice=$(tui_read_choice 4)
    tui_echo ""

    case "$choice" in
        1)
            tui_echo "Offline all E-cores..."
            for cpu in "${e_cores[@]}"; do
                local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
                [[ -f "$online_file" ]] && echo 0 | sudo tee "$online_file" > /dev/null
            done
            tui_ok "All E-cores offline."
            tui_wait
            ;;
        2)
            tui_echo "Online all E-cores..."
            for cpu in "${e_cores[@]}"; do
                local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
                [[ -f "$online_file" ]] && echo 1 | sudo tee "$online_file" > /dev/null
            done
            tui_ok "All E-cores online."
            tui_wait
            ;;
        3)
            tui_echo "Toggle all E-cores..."
            for cpu in "${e_cores[@]}"; do
                local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
                [[ -f "$online_file" ]] || continue
                local state
                state=$(cat "$online_file")
                if [[ "$state" == 1 ]]; then
                    echo 0 | sudo tee "$online_file" > /dev/null
                else
                    echo 1 | sudo tee "$online_file" > /dev/null
                fi
            done
            tui_ok "All E-cores toggled."
            tui_wait
            ;;
        4) tui_mode ;;
        *) tui_err "Invalid option" ; tui_wait ;;
    esac
}

# -----------------------------------------------------------------------

tui_mode() {
    tui_clear

    while true; do
        local turbo_state epp_state gpu_state cores_online ncores
        if [[ -f "/sys/devices/system/cpu/intel_pstate/no_turbo" ]]; then
            if [[ $(cat /sys/devices/system/cpu/intel_pstate/no_turbo) == 0 ]]; then
                turbo_state="Enabled"
            else
                turbo_state="Disabled"
            fi
        else
            turbo_state="N/A"
        fi
        epp_state=$(read_epp)
        gpu_state=$(read_gpu_mode | grep -oiP '(integrated|hybrid|nvidia)' | head -1)
        cores_online=$(cat /sys/devices/system/cpu/online 2>/dev/null || echo "N/A")
        ncores=$(detect_online_cpus 2>/dev/null | wc -w)

        tui_header "$turbo_state" "$gpu_state" "$epp_state" "$cores_online" "$ncores"

        tui_menu_option "1" "Toggle Turbo Boost      [$(tui_status_val "$turbo_state")]"
        tui_menu_option "2" "Configure CPU Cores     [$(tui_status_val "$cores_online")]"
        tui_menu_option "3" "Set Energy Preference   [$(tui_status_val "$epp_state")]"
        tui_menu_option "4" "Set GPU Mode            [$(tui_status_val "${gpu_state:-unknown}")]"
        tui_menu_option "5" "Apply preset mode       (saving / default / performance)"
        tui_menu_option "6" "Save current as profile"
        tui_menu_option "7" "Hybrid CPU Controls"
        tui_menu_option "8" "Exit"
        tui_echo ""

        local choice
        choice=$(tui_read_choice 8)
        tui_echo ""

        case "$choice" in
            1) tui_turbo ;;
            2) tui_cores ;;
            3) tui_epp ;;
            4) tui_gpu ;;
            5) tui_apply_custom ;;
            6) tui_save_profile ;;
            7) tui_hybrid ;;
            8) tui_clear; break ;;
            *) tui_err "Invalid option" ; tui_wait ;;
        esac
    done
}

# --- Turbo ---

tui_turbo() {
    local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"
    if [[ ! -f "$turbo_file" ]]; then
        tui_err "Turbo control not available (intel_pstate not found)."
        tui_wait
        return
    fi

    local current
    current=$(cat "$turbo_file")

    if [[ "$current" == 0 ]]; then
        tui_echo "Turbo Boost is currently ${C_GREEN}Enabled${C_RESET}."
        if tui_confirm "Disable Turbo Boost?"; then
            echo 1 | sudo tee "$turbo_file" > /dev/null
            tui_ok "Turbo Boost disabled."
        fi
    else
        tui_echo "Turbo Boost is currently ${C_RED}Disabled${C_RESET}."
        if tui_confirm "Enable Turbo Boost?"; then
            echo 0 | sudo tee "$turbo_file" > /dev/null
            tui_ok "Turbo Boost enabled."
        fi
    fi
    tui_wait
}

# --- CPU Cores ---

tui_cores() {
    local all_cpus
    mapfile -t all_cpus < <(detect_all_cpus)

    if [[ ${#all_cpus[@]} -eq 0 ]]; then
        tui_err "No CPU cores detected."
        tui_wait
        return
    fi

    tui_echo "${C_BOLD}CPU Cores:${C_RESET}"
    tui_echo ""

    local p_cores=() e_cores=() other_cores=()
    for cpu in "${all_cpus[@]}"; do
        local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
        local label
        label=$(detect_core_type "$cpu")
        local status_text status_color
        if [[ -f "$online_file" ]] && [[ $(cat "$online_file") == 1 ]]; then
            status_text="ONLINE"
            status_color=$C_GREEN
        else
            status_text="OFFLINE"
            status_color=$C_RED
        fi
        printf '    CPU %-3s  %-8s  %s\n' "$cpu" "${status_color}${status_text}${C_RESET}" "${C_DIM}($label)${C_RESET}"

        case "$label" in
            P-core) p_cores+=("$cpu") ;;
            E-core) e_cores+=("$cpu") ;;
            *) other_cores+=("$cpu") ;;
        esac
    done

    tui_echo ""
    tui_echo "${C_DIM}P-cores:${C_RESET} ${p_cores[*]}"
    tui_echo "${C_DIM}E-cores:${C_RESET} ${e_cores[*]}"
    tui_echo "${C_DIM}Other:${C_RESET} ${other_cores[*]}"
    tui_echo ""
    tui_echo "${C_DIM}Enter core numbers to toggle (e.g. 8-11 or 0,2,4,6).${C_RESET}"
    tui_echo "${C_DIM}Leave empty to go back.${C_RESET}"

    local input
    tui_read "Cores to toggle" input

    if [[ -z "$input" ]]; then
        return
    fi

    if tui_confirm "Toggle core(s): $input?"; then
        local toggled=0
        local expanded
        expanded=$(expand_cpu_range "$input")
        for cpu in $expanded; do
            local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
            [[ ! -f "$online_file" ]] && continue
            local state
            state=$(cat "$online_file")
            if [[ "$state" == 1 ]]; then
                echo 0 | sudo tee "$online_file" > /dev/null
            else
                echo 1 | sudo tee "$online_file" > /dev/null
            fi
            ((toggled++))
        done

        local new_online
        new_online=$(cat /sys/devices/system/cpu/online 2>/dev/null)
        if [[ $toggled -gt 0 ]]; then
            tui_ok "Toggled $toggled core(s). Online now: ${C_GREEN}${new_online}${C_RESET}"
        else
            tui_err "No valid cores found in input."
        fi
    fi
    tui_wait
}

# --- EPP ---

tui_epp() {
    local current
    current=$(read_epp)

    tui_echo "${C_BOLD}Energy Performance Preference (EPP)${C_RESET}"
    tui_echo "Current: $(tui_status_val "$current")"
    tui_echo ""
    tui_echo "  ${C_YELLOW}1${C_RESET}) power              ${C_DIM}(max power saving)${C_RESET}"
    tui_echo "  ${C_YELLOW}2${C_RESET}) balance_performance ${C_DIM}(balanced)${C_RESET}"
    tui_echo "  ${C_YELLOW}3${C_RESET}) performance         ${C_DIM}(max performance)${C_RESET}"
    tui_echo "  ${C_YELLOW}4${C_RESET}) cancel"
    tui_echo ""

    local choice
    choice=$(tui_read_choice 4)
    case "$choice" in
        1) apply_epp "power"               && tui_ok "EPP set to: power" ;;
        2) apply_epp "balance_performance"  && tui_ok "EPP set to: balance_performance" ;;
        3) apply_epp "performance"          && tui_ok "EPP set to: performance" ;;
        *) return ;;
    esac
    tui_wait
}

# --- GPU ---

tui_gpu() {
    local current
    current=$(read_gpu_mode | grep -oiP '(integrated|hybrid|nvidia)' | head -1)

    tui_echo "${C_BOLD}GPU Mode${C_RESET}"
    tui_echo "Current: $(tui_status_val "${current:-unknown}")"
    tui_echo ""
    tui_echo "  ${C_YELLOW}1${C_RESET}) integrated   ${C_DIM}(power saving - integrated GPU only)${C_RESET}"
    tui_echo "  ${C_YELLOW}2${C_RESET}) hybrid        ${C_DIM}(default - switchable graphics)${C_RESET}"
    tui_echo "  ${C_YELLOW}3${C_RESET}) nvidia        ${C_DIM}(performance - NVIDIA only)${C_RESET}"
    tui_echo "  ${C_YELLOW}4${C_RESET}) cancel"
    tui_echo ""

    local choice
    choice=$(tui_read_choice 4)
    local mode=""
    case "$choice" in
        1) mode="integrated" ;;
        2) mode="hybrid" ;;
        3) mode="nvidia" ;;
        *) return ;;
    esac

    if tui_confirm "Set GPU mode to: ${mode}?"; then
        sudo envycontrol -s "$mode"
        tui_ok "GPU mode set to: $mode"
        tui_echo "${C_DIM}Note: A restart may be required for GPU changes.${C_RESET}"
    fi
    tui_wait
}

# --- Apply preset ---

tui_apply_custom() {
    tui_echo "${C_BOLD}Apply preset mode:${C_RESET}"
    tui_echo ""
    tui_echo "  ${C_YELLOW}1${C_RESET}) saving       ${C_DIM}(disable turbo, offline E-cores, power EPP)${C_RESET}"
    tui_echo "  ${C_YELLOW}2${C_RESET}) default      ${C_DIM}(turbo on, all cores, balanced EPP)${C_RESET}"
    tui_echo "  ${C_YELLOW}3${C_RESET}) performance  ${C_DIM}(turbo on, all cores, performance EPP)${C_RESET}"
    tui_echo "  ${C_YELLOW}4${C_RESET}) cancel"
    tui_echo ""

    local choice
    choice=$(tui_read_choice 4)
    local mode=""
    case "$choice" in
        1) mode="saving" ;;
        2) mode="default" ;;
        3) mode="performance" ;;
        *) return ;;
    esac

    if tui_confirm "Apply ${C_BOLD}${mode}${C_RESET} mode?"; then
        set_mode "$mode"
        tui_ok "${mode} mode applied."
    fi
    tui_wait
}

# --- Save profile ---

tui_save_profile() {
    tui_echo "${C_BOLD}Save current configuration as profile${C_RESET}"
    tui_echo ""

    local name
    tui_read "Profile name" name

    if [[ -z "$name" ]]; then
        tui_err "Name cannot be empty."
        tui_wait
        return
    fi

    save_mode "$name"
    if [[ $? -eq 0 ]]; then
        tui_ok "Profile '${C_BOLD}$name${C_RESET}' saved."
    fi
    tui_wait
}

# ---------------------------------------------------------------------------
# CLI Dispatch
# ---------------------------------------------------------------------------

case "$1" in
    saving|default|performance)
        set_mode "$1"
        ;;
    info)
        show_info
        ;;
    save)
        if validate_name "$2"; then
            save_mode "$2"
        else
            echo "Error: Name must be alphanumeric (dashes/underscores allowed)."
        fi
        ;;
    apply)
        if [[ -z "$2" ]]; then
            echo "Error: Mode name required."
        elif ! validate_name "$2"; then
            echo "Error: Invalid mode name."
        elif [[ -f "$CUSTOM_DIR/$2.sh" ]]; then
            sudo "$CUSTOM_DIR/$2.sh"
        else
            echo "Error: Mode '$2' not found."
        fi
        ;;
    list)
        list_modes
        ;;
    remove)
        if [[ -z "$2" ]]; then
            echo "Error: Mode name required."
        elif ! validate_name "$2"; then
            echo "Error: Invalid mode name."
        elif [[ -f "$CUSTOM_DIR/$2.sh" ]]; then
            rm "$CUSTOM_DIR/$2.sh"
            echo "Mode '$2' removed."
        else
            echo "Error: Mode '$2' not found."
        fi
        ;;
    tui|interactive)
        tui_mode
        ;;
    --install-deps|install-deps)
        install_all_deps
        ;;
    --check-deps|check-deps)
        echo "Distribution: $(distro_name)"
        echo ""
        check_dependencies --require-all
        echo "All required dependencies are installed."
        ;;
    --distro)
        distro_name
        ;;
    help|*)
        help
        ;;
esac
