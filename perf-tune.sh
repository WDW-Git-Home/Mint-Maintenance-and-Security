#!/bin/bash
# ==============================================================================
# perf-tune.sh — Performance Tuning & Gear Shift Tool
# Author: Dave Wells
# Launch Date: July 2026
# Version: 1.1 — Added Benchmarks + Comparison
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/perf-tune"
BASELINE_DIR="${CONFIG_DIR}/baseline"
STATE_FILE="${CONFIG_DIR}/current-gear"
BENCH_DIR="${CONFIG_DIR}/benchmarks"
LOG_DIR="${CONFIG_DIR}/logs"
mkdir -p "$CONFIG_DIR" "$BASELINE_DIR" "$BENCH_DIR" "$LOG_DIR"

timestamp() { date +%Y%m%d-%H%M%S; }

# Global: Track tool availability
declare -A TOOLS_AVAILABLE

# ==============================================================================
# TOOL DETECTION
# ==============================================================================
check_tool() {
    local tool="$1"
    command -v "$tool" &>/dev/null && TOOLS_AVAILABLE["$tool"]=1 || TOOLS_AVAILABLE["$tool"]=0
}

detect_all_tools() {
    check_tool "sysbench"
    check_tool "hdparm"
    check_tool "fio"
    check_tool "sensors"
    check_tool "nvtop"
    check_tool "stress"
    check_tool "dd"
    check_tool "lscpu"
    check_tool "free"
}

report_tool_status() {
    echo -e "\n${CYAN}=== Tool Availability Report ===${NC}\n"

    echo -e "${BOLD}Benchmarking Tools:${NC}"
    for tool in sysbench hdparm fio stress; do
        if [[ "${TOOLS_AVAILABLE[$tool]}" == "1" ]]; then
            echo -e "  ${GREEN}✓${NC} $tool"
        else
            echo -e "  ${RED}✗${NC} $tool (not installed — some benchmarks unavailable)"
        fi
    done

    echo
    echo -e "${BOLD}Monitoring Tools:${NC}"
    for tool in sensors nvtop; do
        if [[ "${TOOLS_AVAILABLE[$tool]}" == "1" ]]; then
            echo -e "  ${GREEN}✓${NC} $tool"
        else
            echo -e "  ${YELLOW}○${NC} $tool (optional)"
        fi
    done

    echo
    echo -e "${BOLD}System Info Tools:${NC}"
    for tool in lscpu free dd; do
        if [[ "${TOOLS_AVAILABLE[$tool]}" == "1" ]]; then
            echo -e "  ${GREEN}✓${NC} $tool"
        else
            echo -e "  ${RED}✗${NC} $tool (should be installed by default)"
        fi
    done

    echo
    echo -e "${CYAN}Install missing benchmark tools:${NC}"
    echo "  sudo apt install sysbench hdparm fio stress-ng lm-sensors nvtop"
    echo
}

prompt_install_tools() {
    local missing=()

    [[ "${TOOLS_AVAILABLE[sysbench]}" != "1" ]] && missing+=("sysbench")
    [[ "${TOOLS_AVAILABLE[hdparm]}" != "1" ]] && missing+=("hdparm")
    [[ "${TOOLS_AVAILABLE[fio]}" != "1" ]] && missing+=("fio")

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo -e "${GREEN}All benchmark tools are installed.${NC}"
        return 0
    fi

    echo -e "\n${YELLOW}Missing benchmark tools: ${missing[*]}${NC}"
    echo -n "Install now? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return 1

    sudo apt update -qq
    sudo apt install -y "${missing[@]}"
    detect_all_tools
    echo -e "${GREEN}Installation complete.${NC}"
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
get_current_gear() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "N"
}

set_current_gear() {
    echo "$1" > "$STATE_FILE"
}

gear_name() {
    case "$1" in
        N) echo "Neutral (Stock Settings)" ;;
        1) echo "Desktop (Balanced)" ;;
        2) echo "Gaming (Low Latency)" ;;
        3) echo "Virtualization (Throughput)" ;;
        4) echo "Max Performance" ;;
        R) echo "Reverse (Revert to Baseline)" ;;
        *) echo "Unknown" ;;
    esac
}

pause_for_review() {
    echo
    echo -n "Press Enter to continue..."
    read -r
}

# ==============================================================================
# BASELINE CAPTURE
# ==============================================================================
capture_baseline() {
    local SNAPSHOT_DIR="${BASELINE_DIR}/$(timestamp)"
    mkdir -p "$SNAPSHOT_DIR"

    echo -e "\n${CYAN}=== Capturing Baseline ===${NC}\n"

    # CPU info
    if [[ "${TOOLS_AVAILABLE[lscpu]}" == "1" ]]; then
        lscpu > "$SNAPSHOT_DIR/cpu-info.txt" 2>&1
    fi

    # CPU governors
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "$(basename $(dirname $gov)): $(cat $gov)" \
            >> "$SNAPSHOT_DIR/cpu-governors.txt"
    done

    # I/O schedulers
    for disk in /sys/block/sd* /sys/block/nvme*; do
        [[ -d "$disk" ]] || continue
        name=$(basename "$disk")
        scheduler=$(cat "$disk/queue/scheduler" 2>/dev/null || echo "N/A")
        echo "$name: [$scheduler]" >> "$SNAPSHOT_DIR/io-schedulers.txt"
    done

    # Sysctl key tunables
    sysctl vm.swappiness vm.dirty_ratio vm.dirty_background_ratio \
         net.ipv4.conf.all.forwarding kernel.watchdog 2>/dev/null \
        | grep -E '=' > "$SNAPSHOT_DIR/sysctl-baseline.conf" || true

    # Memory
    if [[ "${TOOLS_AVAILABLE[free]}" == "1" ]]; then
        free -h > "$SNAPSHOT_DIR/memory.txt" 2>&1
    fi

    # Disk info
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL > "$SNAPSHOT_DIR/disks.txt" 2>&1 || true

    # GPU info
    lspci | grep -iE 'vga|3d|display' > "$SNAPSHOT_DIR/gpu-pci.txt" 2>&1 || true

    # Store latest baseline pointer
    echo "$SNAPSHOT_DIR" > "${BASELINE_DIR}/latest"

    echo -e "${GREEN}✓ Baseline captured: $SNAPSHOT_DIR${NC}"
    echo -e "${CYAN}Use gear R (Reverse) to restore this snapshot.${NC}"
    echo
}

get_latest_baseline() {
    [[ -f "${BASELINE_DIR}/latest" ]] && cat "${BASELINE_DIR}/latest" || echo ""
}

# ==============================================================================
# GEAR SHIFTS (cleaned up — suppressed tee output)
# ==============================================================================
shift_neutral() {
    local BASELINE
    BASELINE=$(get_latest_baseline)

    if [[ -z "$BASELINE" ]] || [[ ! -d "$BASELINE" ]]; then
        echo -e "${YELLOW}⚠ No baseline exists. Capture one first.${NC}"
        return 1
    fi

    echo -e "\n${CYAN}=== Shifting to NEUTRAL ===${NC}\n"

    # Restore sysctl
    if [[ -f "$BASELINE/sysctl-baseline.conf" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            sudo sysctl -w "${key}=${value}" 2>/dev/null || true
        done < "$BASELINE/sysctl-baseline.conf"
    fi

    # Restore CPU governors
    if [[ -f "$BASELINE/cpu-governors.txt" ]]; then
        while IFS=: read -r cpu governor; do
            gov_file="/sys/devices/system/cpu/${cpu}/cpufreq/scaling_governor"
            [[ -f "$gov_file" ]] && \
                echo "$governor" | sudo tee "$gov_file" > /dev/null 2>&1 || true
        done < "$BASELINE/cpu-governors.txt"
    fi

    # Restore I/O schedulers
    if [[ -f "$BASELINE/io-schedulers.txt" ]]; then
        while IFS=: read -r name rest; do
            scheduler=$(echo "$rest" | grep -oP '\[.*?\]' | tr -d '[]')
            sched_file="/sys/block/${name}/queue/scheduler"
            [[ -n "$scheduler" ]] && [[ -f "$sched_file" ]] && \
                echo "$scheduler" | sudo tee "$sched_file" > /dev/null 2>&1 || true
        done < "$BASELINE/io-schedulers.txt"
    fi

    # Remove persistent configs
    sudo rm -f /etc/sysctl.d/99-perf-tune-*.conf 2>/dev/null || true

    set_current_gear "N"
    echo -e "${GREEN}✓ Shifted to NEUTRAL — baseline restored${NC}"
}

shift_desktop() {
    echo -e "\n${CYAN}=== Shifting to GEAR 1: DESKTOP ===${NC}\n"

    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "ondemand" | sudo tee "$gov" > /dev/null 2>&1 || true
    done

    sudo sysctl -w vm.swappiness=40 vm.dirty_ratio=20 vm.dirty_background_ratio=10 2>/dev/null

    for disk in /sys/block/sd*; do
        [[ -d "$disk" ]] && echo "deadline" | sudo tee "$disk/queue/scheduler" > /dev/null 2>&1 || true
    done

    echo "madvise" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1 || true

    sudo tee /etc/sysctl.d/99-perf-tune-desktop.conf > /dev/null << 'EOF'
vm.swappiness=40
vm.dirty_ratio=20
vm.dirty_background_ratio=10
EOF

    set_current_gear "1"
    echo -e "${GREEN}✓ Shifted to GEAR 1: DESKTOP${NC}"
    echo -e "${CYAN}Tuned for: daily driving, browsing, office apps, media playback${NC}"
}

shift_gaming() {
    echo -e "\n${CYAN}=== Shifting to GEAR 2: GAMING ===${NC}\n"

    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "performance" | sudo tee "$gov" > /dev/null 2>&1 || true
    done

    sudo sysctl -w vm.swappiness=10 vm.dirty_ratio=10 vm.dirty_background_ratio=5 2>/dev/null

    for disk in /sys/block/sd*; do
        [[ -d "$disk" ]] && echo "bfq" | sudo tee "$disk/queue/scheduler" > /dev/null 2>&1 || true
    done

    echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1 || true
    sudo sysctl -w kernel.watchdog=0 2>/dev/null || true

    sudo tee /etc/sysctl.d/99-perf-tune-gaming.conf > /dev/null << 'EOF'
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
kernel.watchdog=0
EOF

    set_current_gear "2"
    echo -e "${GREEN}✓ Shifted to GEAR 2: GAMING${NC}"
    echo -e "${CYAN}Tuned for: gaming, streaming, GPU-intensive applications${NC}"
}

shift_virtualization() {
    echo -e "\n${CYAN}=== Shifting to GEAR 3: VIRTUALIZATION ===${NC}\n"

    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "ondemand" | sudo tee "$gov" > /dev/null 2>&1 || true
    done

    sudo sysctl -w vm.swappiness=1 net.ipv4.conf.all.forwarding=1 2>/dev/null

    for disk in /sys/block/sd* /sys/block/nvme*n*; do
        [[ -d "$disk" ]] || continue
        echo "mq-deadline" | sudo tee "$disk/queue/scheduler" > /dev/null 2>&1 || \
        echo "none" | sudo tee "$disk/queue/scheduler" > /dev/null 2>&1 || true
    done

    echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1 || true

    sudo tee /etc/sysctl.d/99-perf-tune-virt.conf > /dev/null << 'EOF'
vm.swappiness=1
vm.dirty_background_ratio=5
net.ipv4.conf.all.forwarding=1
EOF

    set_current_gear "3"
    echo -e "${GREEN}✓ Shifted to GEAR 3: VIRTUALIZATION${NC}"
    echo -e "${CYAN}Tuned for: Docker, KVM, VirtualBox, container workloads${NC}"
}

shift_max_performance() {
    echo -e "\n${CYAN}=== Shifting to GEAR 4: MAX PERFORMANCE ===${NC}\n"
    echo -e "${RED}⚠️  WARNING: High power/heat. Not recommended for laptops.${NC}"
    echo -e "${RED}         Increases power consumption and thermal output.${NC}\n"
    echo -n "Continue? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Gear shift cancelled."; return 1; }

    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "performance" | sudo tee "$gov" > /dev/null 2>&1 || true
    done

    sudo sysctl -w vm.swappiness=0 vm.dirty_ratio=5 vm.dirty_background_ratio=1 2>/dev/null
    sudo sysctl -w kernel.watchdog=0 kernel.nmi_watchdog=0 2>/dev/null || true
    sudo sysctl -w fs.file-max=2097152 2>/dev/null || true

    for disk in /sys/block/sd* /sys/block/nvme*n*; do
        [[ -d "$disk" ]] || continue
        echo "none" | sudo tee "$disk/queue/scheduler" > /dev/null 2>&1 || true
    done

    echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1 || true

    sudo tee /etc/sysctl.d/99-perf-tune-max.conf > /dev/null << 'EOF'
vm.swappiness=0
vm.dirty_ratio=5
vm.dirty_background_ratio=1
kernel.watchdog=0
kernel.nmi_watchdog=0
fs.file-max=2097152
EOF

    set_current_gear "4"
    echo -e "${GREEN}✓ Shifted to GEAR 4: MAX PERFORMANCE${NC}"
    echo -e "${CYAN}Tuned for: rendering, compilation, compute workloads${NC}"
}

shift_reverse() {
    echo -e "\n${CYAN}=== Shifting to REVERSE (Full Revert) ===${NC}\n"
    echo -n "Confirm? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; return; }
    shift_neutral
}

# ==============================================================================
# BENCHMARK SUITE
# ==============================================================================

benchmark_cpu() {
    local RESULTS_DIR="$1"
    echo -e "\n${CYAN}--- CPU Benchmark ---${NC}\n"

    if [[ "${TOOLS_AVAILABLE[sysbench]}" != "1" ]]; then
        echo -e "${YELLOW}sysbench not installed. Showing CPU info instead.${NC}"
        if [[ "${TOOLS_AVAILABLE[lscpu]}" == "1" ]]; then
            lscpu | tee "$RESULTS_DIR/cpu-info.txt" 2>&1
        else
            cat /proc/cpuinfo | head -30 > "$RESULTS_DIR/cpu-info.txt" 2>&1
            cat "$RESULTS_DIR/cpu-info.txt"
        fi
        return 1
    fi

    echo "Running sysbench CPU prime test (30 seconds)..."
    sysbench cpu --cpu-max-prime=10000 --time=30 run \
        | tee "$RESULTS_DIR/cpu-benchmark.txt" 2>&1

    echo
    echo "Running sysbench thread test (30 seconds)..."
    sysbench threads --threads=16 --time=30 run \
        | tee "$RESULTS_DIR/cpu-threads.txt" 2>&1

    echo -e "${GREEN}✓ CPU benchmark complete${NC}"
}

benchmark_memory() {
    local RESULTS_DIR="$1"
    echo -e "\n${CYAN}--- Memory Benchmark ---${NC}\n"

    if [[ "${TOOLS_AVAILABLE[sysbench]}" != "1" ]]; then
        echo -e "${YELLOW}sysbench not installed. Showing memory info instead.${NC}"
        if [[ "${TOOLS_AVAILABLE[free]}" == "1" ]]; then
            free -h | tee "$RESULTS_DIR/memory-info.txt" 2>&1
            echo
            grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo \
                | tee -a "$RESULTS_DIR/memory-info.txt" 2>&1
        fi
        return 1
    fi

    echo "Running sysbench memory bandwidth test..."
    sysbench memory --memory-block-size=1G --memory-total-size=10G --time=30 run \
        | tee "$RESULTS_DIR/memory-benchmark.txt" 2>&1

    echo -e "${GREEN}✓ Memory benchmark complete${NC}"
}

benchmark_disk() {
    local RESULTS_DIR="$1"
    echo -e "\n${CYAN}--- Disk Benchmark ---${NC}\n"

    # Detect primary disk (where / is mounted)
    # Handles NVMe (nvme1n1p6 → nvme1n1) and SATA (sda3 → sda)
    local ROOT_DEV
    ROOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null || echo "")

    if [[ -z "$ROOT_DEV" ]]; then
        echo -e "${YELLOW}Cannot determine root disk. Falling back to first NVMe/SATA device.${NC}"
        ROOT_DEV=$(lsblk -dn -o NAME | grep -E '^nvme|^sd' | head -1 | awk '{print "/dev/" $1}')
    fi

    local DEVICE=""
    if [[ "$ROOT_DEV" =~ ^/dev/nvme[0-9]+n[0-9]+p[0-9]+$ ]]; then
        # NVMe with partition: nvme1n1p6 → nvme1n1
        DEVICE=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
    elif [[ "$ROOT_DEV" =~ ^/dev/nvme[0-9]+n[0-9]+$ ]]; then
        # NVMe without partition (whole disk)
        DEVICE="$ROOT_DEV"
    elif [[ "$ROOT_DEV" =~ ^/dev/sd[a-z][0-9]+$ ]]; then
        # SATA with partition: sda3 → sda
        DEVICE=$(echo "$ROOT_DEV" | sed 's/[0-9]*$//')
    elif [[ "$ROOT_DEV" =~ ^/dev/sd[a-z]$ ]]; then
        # SATA whole disk
        DEVICE="$ROOT_DEV"
    else
        echo -e "${YELLOW}Unknown device format: $ROOT_DEV${NC}"
        echo "Falling back to first available block device."
        DEVICE=$(lsblk -dn -o NAME | grep -E '^nvme|^sd' | head -1 | awk '{print "/dev/" $1}')
    fi

    echo "Root partition: $ROOT_DEV"
    echo "Target disk device: $DEVICE"
    echo

    # Sequential read with hdparm
    if [[ "${TOOLS_AVAILABLE[hdparm]}" == "1" ]]; then
        echo "Sequential Read Test (hdparm)..."
        sudo hdparm -tT "$DEVICE" 2>&1 | tee "$RESULTS_DIR/disk-hdparm.txt"
        echo
    else
        echo -e "${YELLOW}hdparm not installed. Skipping sequential read test.${NC}"
        echo
    fi

    # Random I/O with fio
    if [[ "${TOOLS_AVAILABLE[fio]}" == "1" ]]; then
        echo "Random Read I/O Test (fio, 30 seconds)..."
        sudo fio --name=randread --ioengine=libaio --iodepth=4 --rw=randread \
            --bs=4k --direct=1 --size=512M --runtime=30 --time_based \
            --group_reporting --filename="$DEVICE" \
            2>&1 | tee "$RESULTS_DIR/disk-fio-randread.txt"

        echo
        echo "Sequential Write I/O Test (fio, 30 seconds)..."
        # Use a temp file on the mounted filesystem instead of raw device for writes
        local MOUNT_POINT
        MOUNT_POINT=$(findmnt -n -o TARGET / 2>/dev/null || echo "/tmp")
        sudo fio --name=seqwrite --ioengine=libaio --iodepth=4 --rw=randwrite \
            --bs=1M --direct=1 --size=512M --runtime=30 --time_based \
            --group_reporting --filename="${MOUNT_POINT}/.fio-temp-test" \
            2>&1 | tee "$RESULTS_DIR/disk-fio-seqwrite.txt"
        sudo rm -f "${MOUNT_POINT}/.fio-temp-test" 2>/dev/null || true
    else
        echo -e "${YELLOW}fio not installed. Running basic dd fallback...${NC}"
        echo
        echo "Sequential read (dd)..."
        sudo dd if="$DEVICE" of=/dev/null bs=1M count=1000 status=progress \
            2>&1 | tee "$RESULTS_DIR/disk-dd-read.txt"
        echo
        echo -e "${YELLOW}(Install fio for comprehensive I/O testing)${NC}"
    fi

    echo -e "${GREEN}✓ Disk benchmark complete${NC}"
}

benchmark_gpu() {
    local RESULTS_DIR="$1"
    echo -e "\n${CYAN}--- GPU Info ---${NC}\n"

    # PCI detection
    lspci | grep -iE 'vga|3d|display' | tee "$RESULTS_DIR/gpu-pci.txt" 2>&1 || true

    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        echo
        echo "NVIDIA GPU Status:"
        nvidia-smi 2>&1 | tee "$RESULTS_DIR/gpu-nvidia.txt" || true
    elif [[ "${TOOLS_AVAILABLE[nvtop]}" == "1" ]]; then
        echo
        echo "GPU Monitor (nvtop available — launch interactively with 'nvtop')"
        echo "GPU detected via lspci (see above)"
    else
        echo
        echo -e "${YELLOW}No GPU monitoring tools detected.${NC}"
        echo "Install nvtop for NVIDIA/AMD GPU monitoring: sudo apt install nvtop"
    fi

    echo -e "${GREEN}✓ GPU info collected${NC}"
}

benchmark_full_suite() {
    local RESULTS_DIR="${BENCH_DIR}/$(timestamp)"
    mkdir -p "$RESULTS_DIR"

    local GEAR
    GEAR=$(get_current_gear)

    echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}     FULL BENCHMARK SUITE                    ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "Current Gear: $GEAR ($(gear_name "$GEAR"))"
    echo -e "Results saved to: $RESULTS_DIR"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"

    # Record which gear was active during benchmark
    echo "$GEAR" > "$RESULTS_DIR/gear-at-benchmark.txt"
    echo "$(date)" > "$RESULTS_DIR/timestamp.txt"

    benchmark_cpu "$RESULTS_DIR"
    benchmark_memory "$RESULTS_DIR"
    benchmark_disk "$RESULTS_DIR"
    benchmark_gpu "$RESULTS_DIR"

    echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Full benchmark suite complete.${NC}"
    echo -e "${GREEN}All results saved to: $RESULTS_DIR${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
}

benchmark_menu() {
    while true; do
        clear
        echo -e "${CYAN}════════════════════════════════════════${NC}"
        echo -e "${CYAN}        BENCHMARK SUITE                  ${NC}"
        echo -e "${CYAN}════════════════════════════════════════${NC}"
        echo
        echo -e "  ${GREEN}1)${NC} CPU Benchmark${NC} ${YELLOW}($([[ "${TOOLS_AVAILABLE[sysbench]}" == "1" ]] && echo "sysbench ready" || echo "needs sysbench"))${NC}"
        echo -e "  ${GREEN}2)${NC} Memory Benchmark${NC} ${YELLOW}($([[ "${TOOLS_AVAILABLE[sysbench]}" == "1" ]] && echo "sysbench ready" || echo "needs sysbench"))${NC}"
        echo -e "  ${GREEN}3)${NC} Disk Benchmark${NC} ${YELLOW}($([[ "${TOOLS_AVAILABLE[hdparm]}" == "1" || "${TOOLS_AVAILABLE[fio]}" == "1" ]] && echo "ready" || echo "needs hdparm/fio"))${NC}"
        echo -e "  ${GREEN}4)${NC} GPU Info"
        echo -e "  ${GREEN}5)${NC} Run Full Benchmark Suite"
        echo -e "  ${GREEN}6)${NC} View Previous Benchmark Results"
        echo -e "  ${GREEN}B)${NC} Back"
        echo
        read -rp "Select option: " bchoice

        local RESULTS_DIR="${BENCH_DIR}/$(timestamp)"

        case "$bchoice" in
            1)
                mkdir -p "$RESULTS_DIR"
                benchmark_cpu "$RESULTS_DIR"
                pause_for_review
                ;;
            2)
                mkdir -p "$RESULTS_DIR"
                benchmark_memory "$RESULTS_DIR"
                pause_for_review
                ;;
            3)
                mkdir -p "$RESULTS_DIR"
                benchmark_disk "$RESULTS_DIR"
                pause_for_review
                ;;
            4)
                mkdir -p "$RESULTS_DIR"
                benchmark_gpu "$RESULTS_DIR"
                pause_for_review
                ;;
            5)
                benchmark_full_suite
                pause_for_review
                ;;
            6)
                view_benchmark_results
                ;;
            [Bb])
                break
                ;;
            *)
                echo "Invalid option."
                sleep 1
                ;;
        esac
    done
}

view_benchmark_results() {
    echo -e "\n${CYAN}=== Previous Benchmark Results ===${NC}\n"

    local dirs=()
    while IFS= read -r d; do
        dirs+=("$d")
    done < <(ls -dt "${BENCH_DIR}"/*/ 2>/dev/null)

    if [[ ${#dirs[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No benchmark results found.${NC}"
        echo "Run a benchmark first."
        return
    fi

    local i=1
    for d in "${dirs[@]}"; do
        local ts=""
        [[ -f "$d/timestamp.txt" ]] && ts=$(cat "$d/timestamp.txt")
        local gear=""
        [[ -f "$d/gear-at-benchmark.txt" ]] && gear=$(cat "$d/gear-at-benchmark.txt")
        local files=$(ls "$d"/*.txt 2>/dev/null | wc -l)
        echo "  ${GREEN}$i)${NC} $(basename $d) — ${ts:-no date} — Gear: ${gear:-?} — ${files} files"
        ((i++))
    done

    echo
    echo -n "View which result set? (number, or Enter to cancel): "
    read -r sel

    [[ -z "$sel" ]] && return
    [[ "$sel" =~ ^[0-9]+$ ]] || { echo "Invalid selection."; return; }

    local idx=$((sel - 1))
    [[ "$idx" -ge 0 && "$idx" -lt ${#dirs[@]} ]] || { echo "Out of range."; return; }

    local target="${dirs[$idx]}"
    echo -e "\n${CYAN}Contents of $(basename "$target"):${NC}\n"

    for f in "$target"/*.txt; do
        [[ -f "$f" ]] || continue
        echo -e "${BOLD}--- $(basename "$f") ---${NC}"
        cat "$f"
        echo
    done

    echo -e "${CYAN}Full path: $target${NC}"
}

# ==============================================================================
# SETTINGS DISPLAY
# ==============================================================================
show_current_settings() {
    echo -e "\n${CYAN}=== Current System Tunables ===${NC}\n"

    echo -e "${BOLD}Kernel Tunables:${NC}"
    sysctl vm.swappiness vm.dirty_ratio vm.dirty_background_ratio \
         net.ipv4.conf.all.forwarding kernel.watchdog 2>/dev/null || true

    echo
    echo -e "${BOLD}CPU Governors:${NC}"
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$gov" ]] && echo "  $(basename $(dirname $gov)): $(cat $gov)"
    done 2>/dev/null || echo "  (not available)"

    echo
    echo -e "${BOLD}I/O Schedulers:${NC}"
    for disk in /sys/block/sd* /sys/block/nvme*n*; do
        [[ -d "$disk" ]] || continue
        echo "  $(basename $disk): $(cat $disk/queue/scheduler 2>/dev/null || echo 'N/A')"
    done 2>/dev/null || echo "  (none detected)"

    echo
    echo -e "${BOLD}Transparent Hugepages:${NC}"
    cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "  (not available)"

    echo
    echo -e "${BOLD}Memory:${NC}"
    free -h 2>/dev/null || echo "  (free command not available)"

    echo
    echo -e "${BOLD}Persistent Perf Configs:${NC}"
    if sudo ls /etc/sysctl.d/99-perf-tune-*.conf &>/dev/null; then
        sudo ls -la /etc/sysctl.d/99-perf-tune-*.conf
    else
        echo "  (none — running on baseline)"
    fi

    echo
}

# ==============================================================================
# COMPARISON VIEW
# ==============================================================================
compare_before_after() {
    echo -e "\n${CYAN}=== Before/After Comparison ===${NC}\n"

    local BASELINE
    BASELINE=$(get_latest_baseline)

    if [[ -z "$BASELINE" ]] || [[ ! -d "$BASELINE" ]]; then
        echo -e "${YELLOW}No baseline exists. Capture one first (Option 1).${NC}"
        return 1
    fi

    echo -e "${BOLD}Comparing baseline snapshot vs current live values${NC}"
    echo -e "Baseline: $BASELINE"
    echo

    # Sysctl comparison
    echo -e "${CYAN}--- Sysctl Tunables ---${NC}"
    printf "%-45s %-15s %-15s\n" "Parameter" "Baseline" "Current"
    printf "%-45s %-15s %-15s\n" "---------" "--------" "-------"

    if [[ -f "$BASELINE/sysctl-baseline.conf" ]]; then
        while IFS='=' read -r key bval; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            bval=$(echo "$bval" | xargs)
            cval=$(sysctl -n "$key" 2>/dev/null || echo "N/A")
            if [[ "$bval" == "$cval" ]]; then
                marker=" ${GREEN}✓${NC}"
            else
                marker=" ${RED}✗${NC}"
            fi
            printf "%-45s %-15s %-15s %b\n" "$key" "$bval" "$cval" "$marker"
        done < "$BASELINE/sysctl-baseline.conf"
    else
        echo "  (no baseline sysctl data)"
    fi

    echo
    echo -e "${CYAN}--- CPU Governors ---${NC}"
    printf "%-20s %-20s %-20s\n" "CPU" "Baseline" "Current"
    printf "%-20s %-20s %-20s\n" "---" "--------" "-------"

    if [[ -f "$BASELINE/cpu-governors.txt" ]]; then
        while IFS=: read -r cpu bgov; do
            bgov=$(echo "$bgov" | xargs)
            cgov=$(cat "/sys/devices/system/cpu/${cpu}/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")
            if [[ "$bgov" == "$cgov" ]]; then
                marker=" ${GREEN}✓${NC}"
            else
                marker=" ${RED}✗${NC}"
            fi
            printf "%-20s %-20s %-20s %b\n" "$cpu" "$bgov" "$cgov" "$marker"
        done < "$BASELINE/cpu-governors.txt"
    else
        echo "  (no baseline CPU data)"
    fi

    echo
    echo -e "${CYAN}--- I/O Schedulers ---${NC}"
    printf "%-15s %-25s %-25s\n" "Disk" "Baseline" "Current"
    printf "%-15s %-25s %-25s\n" "----" "--------" "-------"

    if [[ -f "$BASELINE/io-schedulers.txt" ]]; then
        while IFS=: read -r disk rest; do
            bsched=$(echo "$rest" | grep -oP '\[.*?\]' | tr -d '[]')
            csched=$(cat "/sys/block/${disk}/queue/scheduler" 2>/dev/null | \
                     grep -oP '\[.*?\]' | tr -d '[]' || echo "N/A")
            if [[ "$bsched" == "$csched" ]]; then
                marker=" ${GREEN}✓${NC}"
            else
                marker=" ${RED}✗${NC}"
            fi
            printf "%-15s %-25s %-25s %b\n" "$disk" "$bsched" "$csched" "$marker"
        done < "$BASELINE/io-schedulers.txt"
    else
        echo "  (no baseline I/O data)"
    fi

    echo
    echo -e "${CYAN}✓ = matches baseline  ✗ = differs from baseline${NC}"
    echo
}

# ==============================================================================
# MAIN MENU
# ==============================================================================
show_menu() {
    local current
    current=$(get_current_gear)
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       PERFORMANCE TUNE & GEAR SHIFT        ║${NC}"
    echo -e "${CYAN}║                  v1.1                      ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                            ║${NC}"
    echo -e "${CYAN}║  Current: ${BOLD}[$current]${NC} $(gear_name "$current")     ${CYAN}║${NC}"
    echo -e "${CYAN}║                                            ║${NC}"
    echo -e "${CYAN}╟────────────────────────────────────────────╢${NC}"
    echo -e "${CYAN}║                                            ║${NC}"
    echo -e "${CYAN}║  ${GREEN}1)${NC} Capture Baseline                     ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}2)${NC} Gear Shift Menu                      ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}3)${NC} Show Current Settings                ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}4)${NC} Before/After Comparison              ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}5)${NC} Benchmark Suite                      ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}6)${NC} Tool Availability Report             ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}7)${NC} Install Missing Tools                ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}B)${NC} Back                                 ${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║                                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo
    read -rp "Select option: " opt
}

# ==============================================================================
# GEAR SHIFT SUBMENU
# ==============================================================================
do_gear_shift_menu() {
    while true; do
        local current
        current=$(get_current_gear)
        clear
        echo -e "${CYAN}════════════════════════════════════════${NC}"
        echo -e "${CYAN}        GEAR SHIFT SELECTOR              ${NC}"
        echo -e "${CYAN}════════════════════════════════════════${NC}"
        echo -e "\nCurrent: [$current] $(gear_name "$current")\n"
        echo -e "  ${GREEN}N${NC} — Neutral (revert to baseline)"
        echo -e "  ${GREEN}1${NC} — Desktop (balanced daily use)"
        echo -e "  ${GREEN}2${NC} — Gaming (low latency, max FPS)"
        echo -e "  ${GREEN}3${NC} — Virtualization (Docker/KVM/VMs)"
        echo -e "  ${GREEN}4${NC} — Max Performance ${RED}(not for laptops)${NC}"
        echo -e "  ${RED}R${NC} — Reverse (full revert + cleanup)"
        echo -e "  ${GREEN}B${NC} — Back"
        echo
        read -rp "Shift to gear: " gear

        case "$gear" in
            [Nn]) shift_neutral ;;
            1)    shift_desktop ;;
            2)    shift_gaming ;;
            3)    shift_virtualization ;;
            4)    shift_max_performance ;;
            [Rr]) shift_reverse ;;
            [Bb]) break ;;
            *)    echo "Invalid gear. Try again." ;;
        esac
        pause_for_review
    done
}

# ==============================================================================
# MAIN LOOP
# ==============================================================================
main() {
    detect_all_tools

    while true; do
        show_menu
        case "$opt" in
            1) capture_baseline ;;
            2) do_gear_shift_menu ;;
            3) show_current_settings ;;
            4) compare_before_after ;;
            5) benchmark_menu ;;
            6) report_tool_status; prompt_install_tools ;;
            7) prompt_install_tools ;;
            [Bb]) exit 0 ;;
            *) echo "Invalid option." ;;
        esac
        pause_for_review
    done
}

# Run if executed directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
