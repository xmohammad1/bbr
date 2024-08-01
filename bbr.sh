bash <(curl -LS https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/google-bbr.sh)
# Define the settings
SETTINGS="
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_mem = 33554432 50331648 67108864
net.ipv4.tcp_rmem = 33554432 50331648 67108864
net.ipv4.tcp_wmem = 33554432 50331648 67108864
net.core.somaxconn = 8192
net.core.netdev_max_backlog = 4000
net.ipv4.tcp_max_syn_backlog = 4000
net.ipv4.udp_mem = 33554432 50331648 67108864
net.ipv4.tcp_fastopen = 3
"

# Append the settings to /etc/sysctl.conf
echo "$SETTINGS" >> /etc/sysctl.conf
sysctl -p
echo "System settings have been applied."
