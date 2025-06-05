#!/usr/bin/env bash
set -euo pipefail

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[38;5;34m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Function to display error and exit
error_exit() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}

# Function to display warning
warning() {
  echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Function to display info
info() {
  echo -e "${BLUE}INFO: $1${NC}"
}

# Function to display success
success() {
  echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Check for bash version
if ((BASH_VERSINFO[0] < 4)); then
  error_exit "This script requires Bash version 4 or later"
fi

# Check for required commands
for cmd in dig systemctl apt unbound-control unbound-checkconf chattr; do
  if ! command -v "$cmd" &> /dev/null; then
    if [ "$cmd" = "apt" ]; then
      error_exit "This script requires apt. It appears you're not using a Debian-based system."
    elif [ "$cmd" = "chattr" ]; then
      warning "$cmd not found. Will attempt to install necessary packages."
    else
      warning "$cmd not found. Will attempt to install necessary packages."
    fi
  fi
done

# Validate IP address format
validate_ip() {
  local ip=$1
  local stat=1
  
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  
  return $stat
}

# Check network connectivity
check_connectivity() {
  info "Checking internet connectivity..."
  if ping -c 1 8.8.8.8 &> /dev/null; then
    success "Internet connection is available"
  else
    warning "No internet connection detected. This script requires internet access to install packages and test DNS resolution."
    read -p "Do you want to continue anyway? (y/n): " choice
    if [[ ! $choice =~ ^[Yy]$ ]]; then
      error_exit "Script aborted by user"
    fi
  fi
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  error_exit "This script must be run as root. Try: sudo $0"
fi

# Check connectivity at the beginning
check_connectivity

# DNS options menu function
choose_dns_provider() {
  local choice
  local valid_input=false
  
  echo -e "\n${BLUE}=== DNS Provider Selection ===${NC}"
  echo -e "Please select a DNS provider to use:"
  echo -e "1) ${GREEN}Cloudflare${NC} (1.1.1.1, 1.0.0.1)"
  echo -e "2) ${GREEN}Google${NC} (8.8.8.8, 8.8.4.4)"
  echo -e "3) ${GREEN}Quad9${NC} (9.9.9.9, 149.112.112.112)"
  echo -e "4) ${GREEN}OpenDNS${NC} (208.67.222.222, 208.67.220.220)"
  echo -e "5) ${GREEN}Custom${NC} (specify your own DNS servers)"
  
  while [ "$valid_input" = false ]; do
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
      1)
        primary_dns="1.1.1.1"
        secondary_dns="1.0.0.1"
        provider_name="Cloudflare"
        valid_input=true
        ;;
      2)
        primary_dns="8.8.8.8"
        secondary_dns="8.8.4.4"
        provider_name="Google"
        valid_input=true
        ;;
      3)
        primary_dns="9.9.9.9"
        secondary_dns="149.112.112.112"
        provider_name="Quad9"
        valid_input=true
        ;;
      4)
        primary_dns="208.67.222.222"
        secondary_dns="208.67.220.220"
        provider_name="OpenDNS"
        valid_input=true
        ;;
      5)
        echo -e "\n${YELLOW}Enter custom DNS servers:${NC}"
        
        while true; do
          read -p "Primary DNS server: " primary_dns
          if validate_ip "$primary_dns"; then
            break
          else
            warning "Invalid IP address format. Please enter a valid IP address."
          fi
        done
        
        while true; do
          read -p "Secondary DNS server: " secondary_dns
          if validate_ip "$secondary_dns"; then
            break
          else
            warning "Invalid IP address format. Please enter a valid IP address."
          fi
        done
        
        provider_name="Custom"
        valid_input=true
        ;;
      *)
        warning "Invalid choice. Please enter a number between 1 and 5."
        ;;
    esac
  done
  
  echo -e "\n${GREEN}Selected DNS provider: ${provider_name}${NC}"
  echo -e "Primary DNS: ${primary_dns}"
  echo -e "Secondary DNS: ${secondary_dns}"
  
  # Validate DNS servers by attempting to resolve a domain
  info "Validating DNS servers..."
  if dig @"$primary_dns" google.com +timeout=3 +tries=1 +short &> /dev/null; then
    success "Primary DNS server is responsive"
  else
    warning "Primary DNS server ($primary_dns) appears to be unresponsive or blocked"
    read -p "Continue anyway? (y/n): " continue_choice
    if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
      error_exit "Script aborted by user"
    fi
  fi
  
  if dig @"$secondary_dns" google.com +timeout=3 +tries=1 +short &> /dev/null; then
    success "Secondary DNS server is responsive"
  else
    warning "Secondary DNS server ($secondary_dns) appears to be unresponsive or blocked"
    read -p "Continue anyway? (y/n): " continue_choice
    if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
      error_exit "Script aborted by user"
    fi
  fi
}

# Check resolv.conf status
echo -e "\n${BLUE}=== Checking /etc/resolv.conf ===${NC}"
if [ ! -f /etc/resolv.conf ]; then
  warning "File /etc/resolv.conf does not exist. Creating it..."
  touch /etc/resolv.conf || error_exit "Failed to create /etc/resolv.conf"
fi


# Try to modify the file to test if it's immutable
if touch /etc/resolv.conf 2>/dev/null; then
  info "File /etc/resolv.conf is not immutable"
else
  warning "File /etc/resolv.conf appears to be immutable"
  echo "Attempting to remove immutable attribute..."
  if ! chattr -i /etc/resolv.conf 2>/dev/null; then
    warning "Failed to remove immutable attribute with chattr"
    if ! lsattr /etc/resolv.conf &>/dev/null; then
      warning "lsattr command not available, filesystem may not support immutable attributes"
    else
      attributes=$(lsattr /etc/resolv.conf 2>/dev/null)
      if [[ $attributes == *"i"* ]]; then
        error_exit "File is immutable and cannot be modified. Please check your filesystem permissions."
      fi
    fi
  else
    # Check if we can now modify the file
    if touch /etc/resolv.conf 2>/dev/null; then
      success "Successfully removed immutable attribute"
    else
      error_exit "Failed to modify resolv.conf after removing immutable attribute. Check file permissions."
    fi
  fi
fi

# Ask for DNS provider
choose_dns_provider

# Check if systemd-resolved is installed
echo -e "\n${BLUE}=== Checking for systemd-resolved ===${NC}"
if systemctl list-unit-files systemd-resolved.service &> /dev/null; then
  info "systemd-resolved is installed"
else
  info "systemd-resolved is not installed or not using systemd"
fi

# Installation 
echo -e "\n${BLUE}=== Installing Unbound ===${NC}"
apt update || error_exit "Failed to update package repositories"
if ! DEBIAN_FRONTEND=noninteractive apt install -y unbound; then
  error_exit "Failed to install unbound package"
fi

echo -e "\n${BLUE}=== Setting up Unbound control keys ===${NC}"
if ! unbound-control-setup; then
  warning "Failed to set up unbound control keys. Continuing anyway."
fi

echo -e "\n${BLUE}=== Writing custom Unbound config ===${NC}"
CONF_DIR="/etc/unbound"
CONF_FILE="${CONF_DIR}/unbound.conf"

# Backup existing config
if [ -f "${CONF_FILE}" ]; then
  cp "${CONF_FILE}" "${CONF_FILE}.backup.$(date +%Y%m%d%H%M%S)"
  success "Created backup of unbound configuration"
fi

# Determine number of CPU cores
cores=$(
  getconf _NPROCESSORS_ONLN 2>/dev/null \
  || nproc --all 2>/dev/null \
  || grep -c '^processor' /proc/cpuinfo \
  || echo 2
)

# Ensure at least 2 cores are used
if [ "$cores" -lt 2 ]; then
  cores=2
  info "Setting cores to minimum of 2"
else
  info "Using detected $cores cores"
fi

# Create Unbound configuration directory if it doesn't exist
if [ ! -d "${CONF_DIR}" ]; then
  mkdir -p "${CONF_DIR}" || error_exit "Failed to create unbound configuration directory"
fi

# Write Unbound configuration
echo "Creating unbound configuration file..."
cat > "${CONF_FILE}" <<EOF || error_exit "Failed to write unbound configuration"
server:
    num-threads: ${cores}
    msg-cache-size: 50m         # Increase message cache to 50 MB
    rrset-cache-size: 100m      # Increase RRset cache to 100 MB
    cache-max-ttl: 86400        # Max cache time: 24 hours
    cache-min-ttl: 3600         # Min cache time: 1 hour
    prefetch: yes               # Pre-fetch records before expiration
    do-ip4: yes                 # Support IPv4
    do-ip6: yes                 # Support IPv6
    do-udp: yes                 # Support UDP
    do-tcp: yes                 # Support TCP
    so-reuseport: yes           # Reuse ports for multi-core efficiency
    so-rcvbuf: 4m               # Socket receive buffer: 4 MB
    so-sndbuf: 4m               # Socket send buffer: 4 MB
    interface: 127.0.0.1        # Listen on localhost
    port: 53                    # Standard DNS port
    access-control: 127.0.0.0/8 allow  # Allow local queries
    private-address: 192.168.0.0/16    # Block private ranges
    private-address: 172.16.0.0/12     # Block private ranges
    private-address: 10.0.0.0/8        # Block private ranges
    serve-expired: yes          # Serve expired records
    serve-expired-ttl: 3600     # Serve expired records for 1 hour post-expiration
    verbosity: 1                # Reasonable log level
    use-syslog: yes             # Use system log
    hide-identity: yes          # Hide server info
    hide-version: yes           # Hide version info
    harden-glue: yes            # Harden glue records
    harden-dnssec-stripped: yes # DNSSEC stripping protection
    harden-referral-path: yes   # Hardening against query poisoning
    qname-minimisation: yes     # Minimize data sent in queries

forward-zone:
    name: "."                   # Apply to all domains
    forward-first: no           # Always forward to specified servers
    forward-addr: ${primary_dns}       # Primary DNS
    forward-addr: ${secondary_dns}     # Secondary DNS
EOF

echo -e "\n${BLUE}=== Checking Unbound configuration ===${NC}"
if ! unbound-checkconf; then
  error_exit "Unbound configuration check failed. Please check the error messages above."
fi

echo -e "\n${BLUE}=== Restarting Unbound ===${NC}"
if ! systemctl restart unbound; then
  error_exit "Failed to restart unbound service. Check service status with: systemctl status unbound"
fi

# Check if unbound service is running
if ! systemctl is-active --quiet unbound; then
  error_exit "Unbound service is not running after restart"
fi

echo -e "\n${BLUE}=== Testing DNS ===${NC}"
s=${1:-127.0.0.1}; d=${2:-google.com}
if dig @"$s" "$d" +short +timeout=5 +tries=2 | grep -q .; then
  success "DNS resolution test successful"
else
  warning "DNS resolution test failed. This might indicate an issue with Unbound configuration."
  read -p "Continue with disabling systemd-resolved? (y/n): " continue_choice
  if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
    error_exit "Script aborted by user"
  fi
fi

echo -e "\n${BLUE}=== Stopping and disabling systemd-resolved ===${NC}"
if systemctl list-unit-files systemd-resolved.service &> /dev/null; then
  if systemctl stop systemd-resolved; then
    info "systemd-resolved stopped"
  else
    warning "Failed to stop systemd-resolved"
  fi
  
  if systemctl disable systemd-resolved; then
    success "systemd-resolved disabled"
  else
    warning "Failed to disable systemd-resolved"
  fi
else
  info "systemd-resolved is not installed or not using systemd. Skipping."
fi

echo -e "\n${BLUE}=== Replacing /etc/resolv.conf ===${NC}"
# Remove immutable attribute if it exists
if ! chattr -i /etc/resolv.conf 2>/dev/null; then
  warning "Failed to remove immutable flag from /etc/resolv.conf or flag doesn't exist"
fi

# Remove existing resolv.conf if it's a symlink or file
if [ -L /etc/resolv.conf ] || [ -f /etc/resolv.conf ]; then
  if ! rm -f /etc/resolv.conf; then
    error_exit "Failed to remove existing resolv.conf file"
  fi
fi

# Create new resolv.conf
if ! cat > /etc/resolv.conf <<'EOF'; then
nameserver 127.0.0.1
options edns0 trust-ad
EOF
  error_exit "Failed to create new resolv.conf file"
fi

echo -e "\n${BLUE}=== Locking /etc/resolv.conf ===${NC}"
if ! chattr +i /etc/resolv.conf 2>/dev/null; then
  warning "Failed to set immutable flag on /etc/resolv.conf"
  info "Your resolv.conf file may be overwritten by the system. You might need to manually prevent this."
else
  success "resolv.conf has been protected with the immutable attribute"
fi

# Add DNS management function
add_dns_management_script() {
  echo -e "\n${BLUE}=== Creating DNS Management Script ===${NC}"
  
  cat > /usr/local/bin/manage-dns <<'EOFSCRIPT' || error_exit "Failed to create DNS management script"
#!/usr/bin/env bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[38;5;34m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Function to display error and exit
error_exit() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}

# Function to display warning
warning() {
  echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Function to display info
info() {
  echo -e "${BLUE}INFO: $1${NC}"
}

# Function to display success
success() {
  echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  error_exit "This script must be run as root. Try: sudo $0"
fi

# Validate IP address format
validate_ip() {
  local ip=$1
  local stat=1
  
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  
  return $stat
}

# Function to update DNS settings
update_dns() {
  local primary_dns=$1
  local secondary_dns=$2
  local provider_name=$3
  
  # Validate DNS servers
  if ! validate_ip "$primary_dns"; then
    error_exit "Invalid primary DNS IP address format: $primary_dns"
  fi
  
  if ! validate_ip "$secondary_dns"; then
    error_exit "Invalid secondary DNS IP address format: $secondary_dns"
  fi
  
  # Unlock resolv.conf first
  if ! chattr -i /etc/resolv.conf 2>/dev/null; then
    warning "Failed to remove immutable flag from /etc/resolv.conf or flag doesn't exist"
  fi
  
  # Check if unbound.conf exists
  if [ ! -f /etc/unbound/unbound.conf ]; then
    error_exit "Unbound configuration file not found. Is Unbound installed?"
  fi
  
  # Create backup of unbound.conf
  cp /etc/unbound/unbound.conf /etc/unbound/unbound.conf.backup.$(date +%Y%m%d%H%M%S) || warning "Failed to create backup of unbound.conf"
  
  # Update unbound configuration
  if ! sed -i "/forward-addr:/d" /etc/unbound/unbound.conf; then
    error_exit "Failed to update unbound configuration - could not remove existing forward-addr lines"
  fi
  
  if ! sed -i "/forward-first:/a\\    forward-addr: ${primary_dns}       # Primary DNS\\n    forward-addr: ${secondary_dns}     # Secondary DNS" /etc/unbound/unbound.conf; then
    error_exit "Failed to update unbound configuration - could not add new forward-addr lines"
  fi
  
  # Verify configuration
  if ! unbound-checkconf; then
    error_exit "Updated unbound configuration is invalid. Restoring from backup..."
    cp /etc/unbound/unbound.conf.backup.* /etc/unbound/unbound.conf
    error_exit "Configuration restored from backup, but DNS update failed."
  fi
  
  # Restart unbound
  if ! systemctl restart unbound; then
    error_exit "Failed to restart unbound service"
  fi
  
  # Lock resolv.conf again
  if ! chattr +i /etc/resolv.conf 2>/dev/null; then
    warning "Failed to set immutable flag on /etc/resolv.conf"
  fi
  
  success "DNS settings updated to ${provider_name}"
  echo -e "Primary: ${primary_dns}"
  echo -e "Secondary: ${secondary_dns}"
  
  # Test DNS
  if dig @127.0.0.1 google.com +short +timeout=5 +tries=2 | grep -q .; then
    success "DNS test successful ✅"
  else
    warning "DNS test failed ❌ - Check your unbound configuration and network connectivity"
  fi
}

# Function to show current DNS settings
show_current_dns() {
  echo -e "${BLUE}Current DNS settings:${NC}"
  if [ -f /etc/unbound/unbound.conf ]; then
    grep "forward-addr:" /etc/unbound/unbound.conf | sed 's/^[ \t]*//' || echo "No forward-addr entries found in unbound.conf"
  else
    echo "Unbound configuration file not found"
  fi
  
  echo -e "\n${BLUE}Current resolv.conf:${NC}"
  cat /etc/resolv.conf
}

# Menu
echo -e "${BLUE}===== DNS Management Tool =====${NC}"
show_current_dns

echo -e "\nChoose an option:"
echo -e "1) ${GREEN}Cloudflare${NC} (1.1.1.1, 1.0.0.1)"
echo -e "2) ${GREEN}Google${NC} (8.8.8.8, 8.8.4.4)"
echo -e "3) ${GREEN}Quad9${NC} (9.9.9.9, 149.112.112.112)"
echo -e "4) ${GREEN}OpenDNS${NC} (208.67.222.222, 208.67.220.220)"
echo -e "5) ${GREEN}Custom${NC} (specify your own DNS servers)"
echo -e "6) ${GREEN}Check DNS Status${NC}"
echo -e "7) ${YELLOW}Exit${NC}"

read -p "Enter your choice [1-7]: " choice

case $choice in
  1)
    update_dns "1.1.1.1" "1.0.0.1" "Cloudflare"
    ;;
  2)
    update_dns "8.8.8.8" "8.8.4.4" "Google"
    ;;
  3)
    update_dns "9.9.9.9" "149.112.112.112" "Quad9"
    ;;
  4)
    update_dns "208.67.222.222" "208.67.220.220" "OpenDNS"
    ;;
  5)
    echo -e "\n${YELLOW}Enter custom DNS servers:${NC}"
    
    while true; do
      read -p "Primary DNS server: " primary_dns
      if validate_ip "$primary_dns"; then
        break
      else
        warning "Invalid IP address format. Please enter a valid IP address."
      fi
    done
    
    while true; do
      read -p "Secondary DNS server: " secondary_dns
      if validate_ip "$secondary_dns"; then
        break
      else
        warning "Invalid IP address format. Please enter a valid IP address."
      fi
    done
    
    update_dns "$primary_dns" "$secondary_dns" "Custom"
    ;;
  6)
    echo -e "\n${BLUE}=== Checking DNS Status ===${NC}"
    show_current_dns
    
    echo -e "\n${BLUE}DNS Resolution Test:${NC}"
    if dig @127.0.0.1 google.com +short +timeout=5 +tries=2 | grep -q .; then
      success "DNS resolution is working properly ✅"
    else
      warning "DNS resolution test failed ❌"
    fi
    
    echo -e "\n${BLUE}Unbound Service Status:${NC}"
    systemctl status unbound --no-pager || warning "Could not get unbound service status"
    ;;
  7)
    echo -e "${YELLOW}Exiting...${NC}"
    exit 0
    ;;
  *)
    error_exit "Invalid choice. Exiting."
    ;;
esac
EOFSCRIPT

  chmod +x /usr/local/bin/manage-dns || error_exit "Failed to make DNS management script executable"
  success "DNS management script created at /usr/local/bin/manage-dns"
  info "You can change DNS settings anytime by running: sudo manage-dns"
}

# Create DNS management script
add_dns_management_script

echo -e "\n${GREEN}=== DNS Setup Complete! ===${NC}"
echo -e "Your system is now using ${provider_name} DNS servers through Unbound"
echo -e "${YELLOW}To change DNS providers later, run: sudo manage-dns${NC}"

# Final verification
echo -e "\n${BLUE}=== Final Verification ===${NC}"
if dig @127.0.0.1 google.com +short +timeout=5 +tries=2 | grep -q .; then
  success "DNS resolution check: PASS"
else
  warning "DNS resolution check: FAIL - Some resolvers may be blocked in your network"
  warning "Try changing DNS providers using: sudo manage-dns"
fi

if systemctl is-active --quiet unbound; then
  success "Unbound service status: ACTIVE"
else
  warning "Unbound service status: NOT ACTIVE"
  warning "Try starting the service manually: sudo systemctl start unbound"
fi

echo -e "\n${GREEN}Setup process completed${NC}"
