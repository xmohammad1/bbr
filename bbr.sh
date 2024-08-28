#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)
#Define the module name
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
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100

net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768

# forward ipv4
net.ipv4.ip_forward = 1
EOF
    cat >> /etc/security/limits.conf <<-EOF
*               soft    nofile          1000000
*               hard    nofile          1000000
EOF

echo "ulimit -SHn 1000000" >> /etc/profile
source /etc/profile

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
if [[ $(lsb_release -rs) != "24.04" ]]; then
    remove_old_ssh_conf
    update_sshd_conf
    limits_optimizations
fi
