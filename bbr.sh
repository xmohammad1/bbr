bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)

# Define the settings
# sudo modprobe nf_conntrack
# fs.file-max = 200000
# net.core.rmem_max = 67108864
# net.core.wmem_max = 67108864
# net.core.rmem_default = 65536
# net.core.wmem_default = 65536
# net.core.netdev_max_backlog = 250000
# net.core.somaxconn = 8192
# net.ipv4.tcp_syncookies = 1
# net.ipv4.tcp_tw_reuse = 1
# net.ipv4.tcp_fin_timeout = 10
# net.ipv4.tcp_keepalive_time = 600
# net.ipv4.tcp_max_syn_backlog = 8192

# net.ipv4.tcp_max_tw_buckets = 5000
# net.ipv4.tcp_mem = 25600 51200 102400
# net.ipv4.tcp_rmem = 4096 65536 67108864
# net.ipv4.tcp_wmem = 4096 65536 67108864
# net.ipv4.tcp_mtu_probing = 1

# # Additional settings
# net.ipv4.ip_forward = 1
# net.netfilter.nf_conntrack_max = 2097152
# net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
# net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 60
# net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60
# net.ipv4.conf.all.route_localnet = 1

cat >> /etc/sysctl.conf <<EOF
# Common settings
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fastopen = 3
EOF
sysctl -p
echo "System settings have been applied."
