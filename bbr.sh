#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)
# Define the module name
MODULE_NAME="nf_conntrack"

# Define the path to the configuration file
CONF_FILE="/etc/modules-load.d/${MODULE_NAME}.conf"

# Check if the configuration file already exists
if [ -f "$CONF_FILE" ]; then
    echo "Configuration file $CONF_FILE already exists."
else
    # Create a new configuration file
    echo "$MODULE_NAME" | sudo tee "$CONF_FILE" > /dev/null
fi

# Load the module immediately (without reboot)
sudo modprobe "$MODULE_NAME"

# Verify if the module is loaded
if lsmod | grep -q "$MODULE_NAME"; then
    echo "Module $MODULE_NAME is successfully loaded."
else
    echo "Failed to load the module $MODULE_NAME."
fi

# Define the settings
Sysctl_file="/etc/sysctl.conf"
sudo sed -i '/net\.core\.default_qdisc/d' $Sysctl_file
sudo sed -i '/net\.ipv4\.tcp_congestion_control/d' $Sysctl_file
sudo modprobe nf_conntrack
cat >> $Sysctl_file <<EOF
# Common settings
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Common settings
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0
fs.file-max = 200000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192

net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1

# Additional settings
net.ipv4.ip_forward = 1
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60

net.ipv4.conf.all.route_localnet = 1
EOF
sysctl -p
echo "System settings have been applied."
SSH_PATH="/etc/ssh/sshd_config"
PROF_PATH="/etc/profile"
# Remove old SSH config to prevent duplicates.
remove_old_ssh_conf() {
    ## Remove these lines
    sed -i -e 's/#UseDNS yes/UseDNS no/' \
        -e 's/#Compression no/Compression yes/' \
        -e 's/Ciphers .*/Ciphers aes256-ctr,chacha20-poly1305@openssh.com/' \
        -e '/MaxAuthTries/d' \
        -e '/MaxSessions/d' \
        -e '/TCPKeepAlive/d' \
        -e '/ClientAliveInterval/d' \
        -e '/ClientAliveCountMax/d' \
        -e '/AllowAgentForwarding/d' \
        -e '/AllowTcpForwarding/d' \
        -e '/GatewayPorts/d' \
        -e '/PermitTunnel/d' \
        -e '/X11Forwarding/d' "$SSH_PATH"

}
# Update SSH config
update_sshd_conf() {
    echo "Optimizing SSH..."
    ## Enable TCP keep-alive messages
    echo "TCPKeepAlive yes" | tee -a "$SSH_PATH"

    ## Configure client keep-alive messages
    echo "ClientAliveInterval 3000" | tee -a "$SSH_PATH"
    echo "ClientAliveCountMax 100" | tee -a "$SSH_PATH"

    ## Allow agent forwarding
    echo "AllowAgentForwarding yes" | tee -a "$SSH_PATH"

    ## Allow TCP forwarding
    echo "AllowTcpForwarding yes" | tee -a "$SSH_PATH"

    ## Enable gateway ports
    echo "GatewayPorts yes" | tee -a "$SSH_PATH"

    ## Enable tunneling
    echo "PermitTunnel yes" | tee -a "$SSH_PATH"

    ## Enable X11 graphical interface forwarding
    echo "X11Forwarding yes" | tee -a "$SSH_PATH"

    ## Restart the SSH service to apply the changes
    sudo systemctl restart ssh

    echo "SSH is Optimized."

}
# System Limits Optimizations
limits_optimizations() {
    echo "Optimizing System Limits..."

    ## Clear old ulimits
    sed -i '/ulimit -c/d' $PROF_PATH
    sed -i '/ulimit -d/d' $PROF_PATH
    sed -i '/ulimit -f/d' $PROF_PATH
    sed -i '/ulimit -i/d' $PROF_PATH
    sed -i '/ulimit -l/d' $PROF_PATH
    sed -i '/ulimit -m/d' $PROF_PATH
    sed -i '/ulimit -n/d' $PROF_PATH
    sed -i '/ulimit -q/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH
    sed -i '/ulimit -t/d' $PROF_PATH
    sed -i '/ulimit -u/d' $PROF_PATH
    sed -i '/ulimit -v/d' $PROF_PATH
    sed -i '/ulimit -x/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH


    ## Add new ulimits
    ## The maximum size of core files created.
    echo "ulimit -c unlimited" | tee -a $PROF_PATH

    ## The maximum size of a process's data segment
    echo "ulimit -d unlimited" | tee -a $PROF_PATH

    ## The maximum size of files created by the shell (default option)
    echo "ulimit -f unlimited" | tee -a $PROF_PATH

    ## The maximum number of pending signals
    echo "ulimit -i unlimited" | tee -a $PROF_PATH

    ## The maximum size that may be locked into memory
    echo "ulimit -l unlimited" | tee -a $PROF_PATH

    ## The maximum memory size
    echo "ulimit -m unlimited" | tee -a $PROF_PATH

    ## The maximum number of open file descriptors
    echo "ulimit -n 1048576" | tee -a $PROF_PATH

    ## The maximum POSIX message queue size
    echo "ulimit -q unlimited" | tee -a $PROF_PATH

    ## The maximum stack size
    echo "ulimit -s -H 65536" | tee -a $PROF_PATH
    echo "ulimit -s 32768" | tee -a $PROF_PATH

    ## The maximum number of seconds to be used by each process.
    echo "ulimit -t unlimited" | tee -a $PROF_PATH

    ## The maximum number of processes available to a single user
    echo "ulimit -u unlimited" | tee -a $PROF_PATH

    ## The maximum amount of virtual memory available to the process
    echo "ulimit -v unlimited" | tee -a $PROF_PATH

    ## The maximum number of file locks
    echo "ulimit -x unlimited" | tee -a $PROF_PATH

    echo "System Limits are Optimized."

}
remove_old_ssh_conf
update_sshd_conf
limits_optimizations
# sysctl_optimizations

# sysctl_optimizations() {
#     echo "Optimizing the Network..."

#     sed -i -e '/fs.file-max/d' \
#         -e '/net.core.default_qdisc/d' \
#         -e '/net.core.netdev_max_backlog/d' \
#         -e '/net.core.optmem_max/d' \
#         -e '/net.core.somaxconn/d' \
#         -e '/net.core.rmem_max/d' \
#         -e '/net.core.wmem_max/d' \
#         -e '/net.core.rmem_default/d' \
#         -e '/net.core.wmem_default/d' \
#         -e '/net.ipv4.tcp_rmem/d' \
#         -e '/net.ipv4.tcp_wmem/d' \
#         -e '/net.ipv4.tcp_congestion_control/d' \
#         -e '/net.ipv4.tcp_fastopen/d' \
#         -e '/net.ipv4.tcp_fin_timeout/d' \
#         -e '/net.ipv4.tcp_keepalive_time/d' \
#         -e '/net.ipv4.tcp_keepalive_probes/d' \
#         -e '/net.ipv4.tcp_keepalive_intvl/d' \
#         -e '/net.ipv4.tcp_max_orphans/d' \
#         -e '/net.ipv4.tcp_max_syn_backlog/d' \
#         -e '/net.ipv4.tcp_max_tw_buckets/d' \
#         -e '/net.ipv4.tcp_mem/d' \
#         -e '/net.ipv4.tcp_mtu_probing/d' \
#         -e '/net.ipv4.tcp_notsent_lowat/d' \
#         -e '/net.ipv4.tcp_retries2/d' \
#         -e '/net.ipv4.tcp_sack/d' \
#         -e '/net.ipv4.tcp_dsack/d' \
#         -e '/net.ipv4.tcp_slow_start_after_idle/d' \
#         -e '/net.ipv4.tcp_window_scaling/d' \
#         -e '/net.ipv4.tcp_adv_win_scale/d' \
#         -e '/net.ipv4.tcp_ecn/d' \
#         -e '/net.ipv4.tcp_ecn_fallback/d' \
#         -e '/net.ipv4.tcp_syncookies/d' \
#         -e '/net.ipv4.udp_mem/d' \
#         -e '/net.ipv6.conf.all.disable_ipv6/d' \
#         -e '/net.ipv6.conf.default.disable_ipv6/d' \
#         -e '/net.ipv6.conf.lo.disable_ipv6/d' \
#         -e '/net.unix.max_dgram_qlen/d' \
#         -e '/vm.min_free_kbytes/d' \
#         -e '/vm.swappiness/d' \
#         -e '/vm.vfs_cache_pressure/d' \
#         -e '/net.ipv4.conf.default.rp_filter/d' \
#         -e '/net.ipv4.conf.all.rp_filter/d' \
#         -e '/net.ipv4.conf.all.accept_source_route/d' \
#         -e '/net.ipv4.conf.default.accept_source_route/d' \
#         -e '/net.ipv4.neigh.default.gc_thresh1/d' \
#         -e '/net.ipv4.neigh.default.gc_thresh2/d' \
#         -e '/net.ipv4.neigh.default.gc_thresh3/d' \
#         -e '/net.ipv4.neigh.default.gc_stale_time/d' \
#         -e '/net.ipv4.conf.default.arp_announce/d' \
#         -e '/net.ipv4.conf.lo.arp_announce/d' \
#         -e '/net.ipv4.conf.all.arp_announce/d' \
#         -e '/kernel.panic/d' \
#         -e '/vm.dirty_ratio/d' \
#         -e '/^#/d' \
#         -e '/^$/d' \
#         "$SYS_PATH"

#     cat <<EOF >> "$SYS_PATH"
# ## File system settings
# ## ----------------------------------------------------------------

# # Set the maximum number of open file descriptors
# fs.file-max = 67108864


# ## Network core settings
# ## ----------------------------------------------------------------

# # Specify default queuing discipline for network devices
# net.core.default_qdisc = fq_codel

# # Configure maximum network device backlog
# net.core.netdev_max_backlog = 32768

# # Set maximum socket receive buffer
# net.core.optmem_max = 262144

# # Define maximum backlog of pending connections
# net.core.somaxconn = 65536

# # Configure maximum TCP receive buffer size
# net.core.rmem_max = 33554432

# # Set default TCP receive buffer size
# net.core.rmem_default = 1048576

# # Configure maximum TCP send buffer size
# net.core.wmem_max = 33554432

# # Set default TCP send buffer size
# net.core.wmem_default = 1048576


# ## TCP settings
# ## ----------------------------------------------------------------

# # Define socket receive buffer sizes
# net.ipv4.tcp_rmem = 16384 1048576 33554432

# # Specify socket send buffer sizes
# net.ipv4.tcp_wmem = 16384 1048576 33554432

# # Set TCP congestion control algorithm to BBR
# net.ipv4.tcp_congestion_control = bbr

# # Configure TCP FIN timeout period
# net.ipv4.tcp_fin_timeout = 25

# # Set keepalive time (seconds)
# net.ipv4.tcp_keepalive_time = 1200

# # Configure keepalive probes count and interval
# net.ipv4.tcp_keepalive_probes = 7
# net.ipv4.tcp_keepalive_intvl = 30

# # Define maximum orphaned TCP sockets
# net.ipv4.tcp_max_orphans = 819200

# # Set maximum TCP SYN backlog
# net.ipv4.tcp_max_syn_backlog = 20480

# # Configure maximum TCP Time Wait buckets
# net.ipv4.tcp_max_tw_buckets = 1440000

# # Define TCP memory limits
# net.ipv4.tcp_mem = 65536 1048576 33554432

# # Enable TCP MTU probing
# net.ipv4.tcp_mtu_probing = 1

# # Define minimum amount of data in the send buffer before TCP starts sending
# net.ipv4.tcp_notsent_lowat = 32768

# # Specify retries for TCP socket to establish connection
# net.ipv4.tcp_retries2 = 8

# # Enable TCP SACK and DSACK
# net.ipv4.tcp_sack = 1
# net.ipv4.tcp_dsack = 1

# # Disable TCP slow start after idle
# net.ipv4.tcp_slow_start_after_idle = 0

# # Enable TCP window scaling
# net.ipv4.tcp_window_scaling = 1
# net.ipv4.tcp_adv_win_scale = -2

# # Enable TCP ECN
# net.ipv4.tcp_ecn = 1
# net.ipv4.tcp_ecn_fallback = 1

# # Enable the use of TCP SYN cookies to help protect against SYN flood attacks
# net.ipv4.tcp_syncookies = 1


# ## UDP settings
# ## ----------------------------------------------------------------

# # Define UDP memory limits
# net.ipv4.udp_mem = 65536 1048576 33554432


# ## IPv6 settings
# ## ----------------------------------------------------------------

# # Enable IPv6
# net.ipv6.conf.all.disable_ipv6 = 0

# # Enable IPv6 by default
# net.ipv6.conf.default.disable_ipv6 = 0

# # Enable IPv6 on the loopback interface (lo)
# net.ipv6.conf.lo.disable_ipv6 = 0


# ## UNIX domain sockets
# ## ----------------------------------------------------------------

# # Set maximum queue length of UNIX domain sockets
# net.unix.max_dgram_qlen = 256


# ## Virtual memory (VM) settings
# ## ----------------------------------------------------------------

# # Specify minimum free Kbytes at which VM pressure happens
# vm.min_free_kbytes = 65536

# # Define how aggressively swap memory pages are used
# vm.swappiness = 10

# # Set the tendency of the kernel to reclaim memory used for caching of directory and inode objects
# vm.vfs_cache_pressure = 250


# ## Network Configuration
# ## ----------------------------------------------------------------

# # Configure reverse path filtering
# net.ipv4.conf.default.rp_filter = 2
# net.ipv4.conf.all.rp_filter = 2

# # Disable source route acceptance
# net.ipv4.conf.all.accept_source_route = 0
# net.ipv4.conf.default.accept_source_route = 0

# # Neighbor table settings
# net.ipv4.neigh.default.gc_thresh1 = 512
# net.ipv4.neigh.default.gc_thresh2 = 2048
# net.ipv4.neigh.default.gc_thresh3 = 16384
# net.ipv4.neigh.default.gc_stale_time = 60

# # ARP settings
# net.ipv4.conf.default.arp_announce = 2
# net.ipv4.conf.lo.arp_announce = 2
# net.ipv4.conf.all.arp_announce = 2

# # Kernel panic timeout
# kernel.panic = 1

# # Set dirty page ratio for virtual memory
# vm.dirty_ratio = 20
# EOF

#     sudo sysctl -p
#     echo "Network is Optimized."
# }
