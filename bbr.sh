#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)
#Define the module name
# MODULE_NAME="nf_conntrack"

# # Define the path to the configuration file
# CONF_FILE="/etc/modules-load.d/${MODULE_NAME}.conf"

# # Check if the configuration file already exists
# if [ -f "$CONF_FILE" ]; then
#     echo "Configuration file $CONF_FILE already exists."
# else
#     # Create a new configuration file
#     echo "$MODULE_NAME" | sudo tee "$CONF_FILE" > /dev/null
# fi

# # Load the module immediately (without reboot)
# sudo modprobe "$MODULE_NAME"

# # Verify if the module is loaded
# if lsmod | grep -q "$MODULE_NAME"; then
#     echo "Module $MODULE_NAME is successfully loaded."
# else
#     echo "Failed to load the module $MODULE_NAME."
# fi

# Define the settings
Sysctl_file="/etc/sysctl.conf"
sudo sed -i '/net\.core\.default_qdisc/d' $Sysctl_file
sudo sed -i '/net\.ipv4\.tcp_congestion_control/d' $Sysctl_file

cat >> $Sysctl_file <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_ecn=2

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
