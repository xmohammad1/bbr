# Network Performance Optimization Tools

This repository contains scripts to optimize network performance on Linux systems.

## Core Features

### TCP BBR + sysctl Configuration

Improves network throughput and reduces latency:

```bash
bash <(curl -LS https://raw.githubusercontent.com/xmohammad1/bbr/main/bbr.sh)
```

## Optional Enhancements
## Optione 1
### Systemd DNS Optimizer

Improves DNS resolution performance:

```bash
bash <(curl -LS https://raw.githubusercontent.com/xmohammad1/bbr/main/optimized-systemd-dns.sh)
```
## Optione 2
### Unbound DNS Configuration

or you can Sets up Unbound as a local DNS resolver for improved and performance:

```bash
bash <(curl -LS https://raw.githubusercontent.com/xmohammad1/bbr/main/set-unbound-dns.sh)
```
## Optione 3
### Direct DNS
```
cat /etc/resolv.conf && sudo rm -f /etc/resolv.conf && echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null && cat /etc/resolv.conf && sudo systemctl stop systemd-resolved && sudo systemctl disable systemd-resolved
```
