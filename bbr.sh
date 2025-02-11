#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
sudo apt -q update
sudo apt -y upgrade
sudo apt -y full-upgrade
sudo apt -y autoremove
sleep 0.5

## Again :D
sudo apt -y -q autoclean
sudo apt -y clean
sudo apt -q update
sudo apt -y upgrade
sudo apt -y full-upgrade
sudo apt -y autoremove --purge
## Networking packages
sudo apt -y install apt-transport-https

## System utilities
sudo apt -y install apt-utils bash-completion busybox ca-certificates cron curl gnupg2 locales lsb-release nano preload screen software-properties-common ufw unzip vim wget xxd zip

## Programming and development tools
sudo apt -y install autoconf automake bash-completion build-essential git libtool make pkg-config python3 python3-pip

## Additional libraries and dependencies
sudo apt -y install bc binutils binutils-common binutils-x86-64-linux-gnu ubuntu-keyring haveged jq libsodium-dev libsqlite3-dev libssl-dev packagekit qrencode socat

## Miscellaneous
sudo apt -y install dialog htop net-tools
sudo systemctl enable cron haveged preload
## Clear old ulimits
sed -i '/ulimit -c/d' "/etc/profile"
sed -i '/ulimit -d/d' "/etc/profile"
sed -i '/ulimit -f/d' "/etc/profile"
sed -i '/ulimit -i/d' "/etc/profile"
sed -i '/ulimit -l/d' "/etc/profile"
sed -i '/ulimit -m/d' "/etc/profile"
sed -i '/ulimit -n/d' "/etc/profile"
sed -i '/ulimit -q/d' "/etc/profile"
sed -i '/ulimit -s/d' "/etc/profile"
sed -i '/ulimit -t/d' "/etc/profile"
sed -i '/ulimit -u/d' "/etc/profile"
sed -i '/ulimit -v/d' "/etc/profile"
sed -i '/ulimit -x/d' "/etc/profile"
sed -i '/ulimit -s/d' "/etc/profile"


## Add new ulimits
## The maximum size of core files created.
echo "ulimit -c unlimited" | tee -a "/etc/profile"

## The maximum size of a process's data segment
echo "ulimit -d unlimited" | tee -a "/etc/profile"

## The maximum size of files created by the shell (default option)
echo "ulimit -f unlimited" | tee -a "/etc/profile"

## The maximum number of pending signals
echo "ulimit -i unlimited" | tee -a "/etc/profile"

## The maximum size that may be locked into memory
echo "ulimit -l unlimited" | tee -a "/etc/profile"

## The maximum memory size
echo "ulimit -m unlimited" | tee -a "/etc/profile"

## The maximum number of open file descriptors
echo "ulimit -n 1048576" | tee -a "/etc/profile"

## The maximum POSIX message queue size
echo "ulimit -q unlimited" | tee -a "/etc/profile"

## The maximum stack size
echo "ulimit -s -H 65536" | tee -a "/etc/profile"
echo "ulimit -s 32768" | tee -a "/etc/profile"

## The maximum number of seconds to be used by each process.
echo "ulimit -t unlimited" | tee -a "/etc/profile"

## The maximum number of processes available to a single user
echo "ulimit -u unlimited" | tee -a "/etc/profile"

## The maximum amount of virtual memory available to the process
echo "ulimit -v unlimited" | tee -a "/etc/profile"

## The maximum number of file locks
echo "ulimit -x unlimited" | tee -a "/etc/profile"
# Increase limits for open file descriptors; this can help if your VPN handles many connections.
LIMITS_CONF="/etc/security/limits.conf"
# Only append if the entries are not already present.
if ! grep -q "nofile 65535" "${LIMITS_CONF}"; then
  cat <<'EOF' >> ${LIMITS_CONF}

# Increase maximum number of open file descriptors for all users
* soft nofile 65535
* hard nofile 65535
EOF
  echo "File descriptor limits updated in ${LIMITS_CONF}."
else
  echo "File descriptor limits already set in ${LIMITS_CONF}."
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


# Define the settings
Sysctl_file="/etc/sysctl.d/hiddify.conf"

cat >> $Sysctl_file <<EOF
# Common settings
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
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192

net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_mtu_probing = 1

# Additional settings
net.ipv4.ip_forward = 1
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60
EOF
    cat >> /etc/security/limits.conf <<-EOF
*               soft    nofile          1000000
*               hard    nofile          1000000
EOF

echo "ulimit -SHn 1000000" >> /etc/profile
source /etc/profile

sysctl --system
