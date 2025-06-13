#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
Sysctl_file="/etc/sysctl.conf"
bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)
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

net.ipv4.conf.all.route_localnet = 1
EOF

cat <<EOL > /etc/security/limits.conf
* soft nproc 655350
* hard nproc 655350
* soft nofile 655350
* hard nofile 655350
root soft nproc 655350
root hard nproc 655350
root soft nofile 655350
root hard nofile 655350
EOL

sysctl -p
