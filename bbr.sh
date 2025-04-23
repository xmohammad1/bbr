#!/bin/bash
HOST_PATH="/etc/hosts"
if ! grep -q $(hostname) $HOST_PATH; then
echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
echo "Hosts Fixed."
fi
Sysctl_file="/etc/sysctl.conf"
sudo modprobe tcp_bbr
echo tcp_bbr | sudo tee /etc/modules-load.d/tcp_bbr.conf
bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)
cat >> $Sysctl_file <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
fs.file-max = 1000000
net.core.somaxconn = 65536
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.conf.all.rp_filter = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.netdev_max_backlog = 250000
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
kernel.threads-max = 100000
kernel.pid_max = 100000
vm.max_map_count = 262144
EOF

cat >> /etc/security/limits.conf <<-EOF
*               soft    nofile          1000000
*               hard    nofile          1000000
EOF

echo "ulimit -SHn 1000000" >> /etc/profile
source /etc/profile

sysctl -p
