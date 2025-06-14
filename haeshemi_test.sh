#!/usr/bin/env bash
#
# Optimise kernel (sysctl) parameters and user/system limits.
# Run this script as root.

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────
SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_BAK="/etc/sysctl.conf.bak"
PROFILE="/etc/profile"

# ── ANSI colours ───────────────────────────────────────────────
CLR_BLACK="\033[30m"
CLR_RED="\033[31m"
CLR_GREEN="\033[32m"
CLR_YELLOW="\033[33m"
CLR_BLUE="\033[34m"
CLR_MAGENTA="\033[35m"
CLR_CYAN="\033[36m"
CLR_WHITE="\033[37m"
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_UNDERLINE="\033[4m"

ok()    { echo -e "${CLR_GREEN}[OK]${CLR_RESET}  $*";     }
info()  { echo -e "${CLR_YELLOW}[INFO]${CLR_RESET} $*";   }
die()   { echo -e "${CLR_RED}[ERR]${CLR_RESET}  $*" >&2; exit 1; }

# ── Sysctl tweaks ──────────────────────────────────────────────
sysctl_optimisations() {
    cp -a "$SYSCTL_CONF" "$SYSCTL_BAK"
    info "Backed-up sysctl.conf to $SYSCTL_BAK"

    # Remove old blocks we added (keeps script re-entrant)
    sed -i '/^# BEGIN TUNING/,/^# END TUNING/d' "$SYSCTL_CONF"

    cat <<'EOF' >>"$SYSCTL_CONF"
# BEGIN TUNING – added by tuning script
fs.file-max = 67108864
net.core.default_qdisc = fq_codel
net.core.netdev_max_backlog = 32768
net.core.optmem_max = 262144
net.core.somaxconn = 65536
net.core.rmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_max = 33554432
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 16384 1048576 33554432
net.ipv4.tcp_wmem = 16384 1048576 33554432
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 25
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_orphans = 819200
net.ipv4.tcp_max_syn_backlog = 20480
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mem = 65536 1048576 33554432
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.udp_mem = 65536 1048576 33554432
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.unix.max_dgram_qlen = 256
vm.min_free_kbytes = 65536
vm.swappiness = 10
vm.vfs_cache_pressure = 250
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
kernel.panic = 1
vm.dirty_ratio = 20
# END TUNING – added by tuning script
EOF

    sysctl -p
    ok "Kernel parameters applied"
}

# ── Limits ─────────────────────────────────────────────────────
limits_optimisations() {
    info "Updating ulimit / pam-limits …"

    # Remove anything we previously inserted
    sed -i '/^# BEGIN ULIMIT/,/^# END ULIMIT/d' "$PROFILE"

    cat <<'EOF' >>"$PROFILE"
# BEGIN ULIMIT – added by tuning script
ulimit -c unlimited
ulimit -d unlimited
ulimit -f unlimited
ulimit -i unlimited
ulimit -l unlimited
ulimit -m unlimited
ulimit -n 1048576
ulimit -q unlimited
ulimit -s -H 65536
ulimit -s 32768
ulimit -t unlimited
ulimit -u unlimited
ulimit -v unlimited
ulimit -x unlimited
# END ULIMIT – added by tuning script
EOF

    ok "System limits updated (you’ll need to log out/in)"
}

# ── Ask for reboot ─────────────────────────────────────────────
ask_reboot() {
    printf "${CLR_YELLOW}Reboot now? (recommended) [y/N]: ${CLR_RESET}"
    read -r reply || true
    if [[ "${reply,,}" == "y" ]]; then
        info "Rebooting…"
        reboot
    fi
}

# ── Main ───────────────────────────────────────────────────────
sysctl_optimisations
limits_optimisations
ask_reboot
