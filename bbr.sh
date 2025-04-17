#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
sudo modprobe tcp_bbr
bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)

if [[ $(lsb_release -rs) != "24.04" ]]; then
    # Define the settings
    Sysctl_file="/etc/sysctl.conf"
    sudo sed -i '/net\.core\.default_qdisc/d' $Sysctl_file
    sudo sed -i '/net\.ipv4\.tcp_congestion_control/d' $Sysctl_file
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
    sudo modprobe "$MODULE_NAME"
    cat >> $Sysctl_file <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

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
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192

net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1

# net.core.default_qdisc=fq
# net.ipv4.tcp_congestion_control=bbr

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
fi
sysctl -p
