SYS_PATH="/etc/sysctl.conf"
PROF_PATH="/etc/profile"
black="\033[30m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
magenta="\033[35m"
cyan="\033[36m"
white="\033[37m"
reset="\033[0m"
normal="\033[0m"
bold="\033[1m"
underline="\033[4m"
sysctl_optimizations() {
cp $SYS_PATH /etc/sysctl.conf.bak
echo
echo -e "${YELLOW}Default sysctl.conf file Saved. Directory: /etc/sysctl.conf.bak${NC}"
echo
sleep 1
echo
echo -e  "${YELLOW}Optimizing the Network...${NC}"
echo
sleep 0.5
sed -i -e '/fs.file-max/d' \
-e '/net.core.default_qdisc/d' \
-e '/net.core.netdev_max_backlog/d' \
-e '/net.core.optmem_max/d' \
-e '/net.core.somaxconn/d' \
-e '/net.core.rmem_max/d' \
-e '/net.core.wmem_max/d' \
-e '/net.core.rmem_default/d' \
-e '/net.core.wmem_default/d' \
-e '/net.ipv4.tcp_rmem/d' \
-e '/net.ipv4.tcp_wmem/d' \
-e '/net.ipv4.tcp_congestion_control/d' \
-e '/net.ipv4.tcp_fastopen/d' \
-e '/net.ipv4.tcp_fin_timeout/d' \
-e '/net.ipv4.tcp_keepalive_time/d' \
-e '/net.ipv4.tcp_keepalive_probes/d' \
-e '/net.ipv4.tcp_keepalive_intvl/d' \
-e '/net.ipv4.tcp_max_orphans/d' \
-e '/net.ipv4.tcp_max_syn_backlog/d' \
-e '/net.ipv4.tcp_max_tw_buckets/d' \
-e '/net.ipv4.tcp_mem/d' \
-e '/net.ipv4.tcp_mtu_probing/d' \
-e '/net.ipv4.tcp_notsent_lowat/d' \
-e '/net.ipv4.tcp_retries2/d' \
-e '/net.ipv4.tcp_sack/d' \
-e '/net.ipv4.tcp_dsack/d' \
-e '/net.ipv4.tcp_slow_start_after_idle/d' \
-e '/net.ipv4.tcp_window_scaling/d' \
-e '/net.ipv4.tcp_adv_win_scale/d' \
-e '/net.ipv4.tcp_ecn/d' \
-e '/net.ipv4.tcp_ecn_fallback/d' \
-e '/net.ipv4.tcp_syncookies/d' \
-e '/net.ipv4.udp_mem/d' \
-e '/net.ipv6.conf.all.disable_ipv6/d' \
-e '/net.ipv6.conf.default.disable_ipv6/d' \
-e '/net.ipv6.conf.lo.disable_ipv6/d' \
-e '/net.unix.max_dgram_qlen/d' \
-e '/vm.min_free_kbytes/d' \
-e '/vm.swappiness/d' \
-e '/vm.vfs_cache_pressure/d' \
-e '/net.ipv4.conf.default.rp_filter/d' \
-e '/net.ipv4.conf.all.rp_filter/d' \
-e '/net.ipv4.conf.all.accept_source_route/d' \
-e '/net.ipv4.conf.default.accept_source_route/d' \
-e '/net.ipv4.neigh.default.gc_thresh1/d' \
-e '/net.ipv4.neigh.default.gc_thresh2/d' \
-e '/net.ipv4.neigh.default.gc_thresh3/d' \
-e '/net.ipv4.neigh.default.gc_stale_time/d' \
-e '/net.ipv4.conf.default.arp_announce/d' \
-e '/net.ipv4.conf.lo.arp_announce/d' \
-e '/net.ipv4.conf.all.arp_announce/d' \
-e '/kernel.panic/d' \
-e '/vm.dirty_ratio/d' \
-e '/^#/d' \
-e '/^$/d' \
"$SYS_PATH"
cat <<EOF >> "$SYS_PATH"
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
EOF
sudo sysctl -p
echo
echo -e "${GREEN}Network is Optimized.${NC}"
echo
sleep 0.5
}
limits_optimizations() {
echo
echo -e "${YELLOW}Optimizing System Limits...${NC}"
echo
sleep 0.5
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
echo "ulimit -c unlimited" | tee -a $PROF_PATH
echo "ulimit -d unlimited" | tee -a $PROF_PATH
echo "ulimit -f unlimited" | tee -a $PROF_PATH
echo "ulimit -i unlimited" | tee -a $PROF_PATH
echo "ulimit -l unlimited" | tee -a $PROF_PATH
echo "ulimit -m unlimited" | tee -a $PROF_PATH
echo "ulimit -n 1048576" | tee -a $PROF_PATH
echo "ulimit -q unlimited" | tee -a $PROF_PATH
echo "ulimit -s -H 65536" | tee -a $PROF_PATH
echo "ulimit -s 32768" | tee -a $PROF_PATH
echo "ulimit -t unlimited" | tee -a $PROF_PATH
echo "ulimit -u unlimited" | tee -a $PROF_PATH
echo "ulimit -v unlimited" | tee -a $PROF_PATH
echo "ulimit -x unlimited" | tee -a $PROF_PATH
echo
echo -e "${GREEN}System Limits are Optimized.${NC}"
echo
sleep 0.5
}
ask_reboot() {
echo -ne "${YELLOW}Reboot now? (Recommended) (y/n): ${NC}"
while true; do
read choice
echo
if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
sleep 0.5
reboot
exit 0
fi
if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
break
fi
done
}
sysctl_optimizations
limits_optimizations
ask_reboot
