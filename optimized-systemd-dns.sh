GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}      DNS Configuration Utility v1.0             ${NC}"
echo -e "${BLUE}=================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script requires root privileges.${NC}"
  echo -e "Please run with sudo: ${YELLOW}sudo $0${NC}"
  exit 1
fi

echo -e "\n${GREEN}Starting DNS configuration...${NC}"




echo "Starting DNS configuration cleanup..."
echo "Keeping main config: /etc/systemd/resolved.conf"


find /etc/systemd -type f -path "*/resolved.conf*" ! -path "/etc/systemd/resolved.conf" | while read -r file; do
    echo "Found extra DNS config: $file"
    echo "Removing: $file"
    rm -v "$file"
done

if [ -d "/etc/systemd/resolved.conf.d" ]; then
    echo "Found resolved.conf.d directory with extra configs:"
    find /etc/systemd/resolved.conf.d -type f | while read -r file; do
        echo "Removing: $file"
        rm -v "$file"
    done

    if [ -z "$(ls -A /etc/systemd/resolved.conf.d)" ]; then
        echo "Directory /etc/systemd/resolved.conf.d is now empty, removing it."
        rmdir -v /etc/systemd/resolved.conf.d
    fi
fi

echo "DNS configuration cleanup completed."

setup_dns() {
  echo -e "\n${YELLOW}Step 1: Preparing system files...${NC}"

  echo "Checking resolv.conf attributes..."
  if lsattr /etc/resolv.conf 2>/dev/null | grep -q "i"; then
    echo "Removing immutable flag from /etc/resolv.conf"
    chattr -i /etc/resolv.conf
  fi

  if [ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
    resolv_backup="/etc/resolv.conf.bak.$(date +%F-%T)"
    echo "Backing up original /etc/resolv.conf to $resolv_backup"
    cp /etc/resolv.conf "$resolv_backup"
  fi

  config_file="/etc/systemd/resolved.conf"
  backup_file="$config_file.bak.$(date +%F-%T)"
  
  if [ -f "$config_file" ]; then
    echo "Creating backup of existing configuration at $backup_file"
    cp "$config_file" "$backup_file"
  else
    echo "Warning: $config_file not found, creating new one"
  fi

  echo -e "\n${YELLOW}Step 2: Applying new DNS settings...${NC}"

  cat > "$config_file" <<EOL


[Resolve]
DNS=1.1.1.1 8.8.8.8
DNSStubListener=no
Cache=yes
CacheFromLocalhost=no
DNSSEC=no
DNSOverTLS=no
LLMNR=no
MulticastDNS=no
ReadEtcHosts=no
EOL

  echo "DNS settings applied to $config_file"

  echo -e "\n${YELLOW}Step 3: Updating resolv.conf...${NC}"

  if [ -L /etc/resolv.conf ]; then
    echo "Removing existing symbolic link /etc/resolv.conf"
    rm /etc/resolv.conf
  elif [ -f /etc/resolv.conf ]; then
    echo "Removing existing file /etc/resolv.conf"
    rm /etc/resolv.conf
  elif [ -e /etc/resolv.conf ]; then
    echo "Removing existing /etc/resolv.conf (unknown type)"
    rm -f /etc/resolv.conf
  fi

  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  echo "Created symlink: /etc/resolv.conf -> /run/systemd/resolve/resolv.conf"

  echo -e "\n${YELLOW}Step 4: Applying changes...${NC}"
  systemctl restart systemd-resolved

  if systemctl is-active --quiet systemd-resolved; then
    echo -e "${GREEN}systemd-resolved service restarted successfully${NC}"
  else
    echo -e "${RED}Warning: systemd-resolved service failed to restart${NC}"
    echo "Please check system logs for details"
  fi
}

show_current_dns() {
  echo -e "\n${YELLOW}Current DNS Configuration:${NC}"
  echo -e "${BLUE}---------------------------${NC}"
  
  if systemctl is-active --quiet systemd-resolved; then
    echo "systemd-resolved status:"
    resolvectl status | grep "DNS Server" || echo "No DNS servers found in resolvectl"
  else
    echo "systemd-resolved is not running"
  fi

  if [ -L /etc/resolv.conf ]; then
    echo -e "\nSymlink target: $(readlink -f /etc/resolv.conf)"
  fi
}

setup_dns
show_current_dns

echo -e "\n${GREEN}DNS Configuration Complete!${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "DNS servers set to: Cloudflare (1.1.1.1, 8.8.8.8)"
echo -e "                    Google    (8.8.8.8, 8.8.4.4)"
echo -e "${BLUE}==================================================${NC}"
echo -e "You can test your DNS setup with: ${YELLOW}dig example.com${NC}"
echo -e "If you experience any issues, the backup is at: ${YELLOW}$backup_file${NC}\n"

echo -n "Do you want to also change DNS on netplan? (y/n): "
read -r answer

if [[ $answer =~ ^[Yy] ]]; then





if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed. Please install it (e.g., sudo apt update && sudo apt install python3)."
    exit 1
fi
if ! python3 -c "import yaml" &> /dev/null; then
    echo "Error: PyYAML module for Python3 is not installed. Please install it (e.g., sudo apt update && sudo apt install python3-yaml)."
    exit 1
fi

COMMENT_HEADER="# This file is generated from information provided by the datasource.  Changes





NETPLAN_DIR="/etc/netplan"
NETPLAN_CONFIG=""
BACKUP_FILE="" # Initialize backup file variable




mapfile -d '' netplan_configs < <(find "$NETPLAN_DIR" -maxdepth 1 -type f \( -name '*.yaml' ! -name '*.bak' ! -name '*.old' ! -name '*.orig' \) -print0 2>/dev/null)

if (( ${#netplan_configs[@]} > 0 )); then
    echo "Found Netplan configurations:"
    printf '  - %s\n' "${netplan_configs[@]}"
    NETPLAN_CONFIG="${netplan_configs[0]}" # Select first file
else
    echo "No Netplan configurations found"
fi

if [ -z "$NETPLAN_CONFIG" ]; then
    echo "No existing Netplan configuration found in $NETPLAN_DIR"

else
    echo "Processing existing configuration: $NETPLAN_CONFIG"

    BACKUP_FILE="$NETPLAN_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    cp "$NETPLAN_CONFIG" "$BACKUP_FILE"
    echo "Created backup at $BACKUP_FILE"


    MODIFIED_YAML=$(python3 -c "
import yaml
import sys
import io

try:
    with open('$NETPLAN_CONFIG', 'r') as f:
        config = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f'Error parsing YAML: {e}', file=sys.stderr)
    sys.exit(1)
except FileNotFoundError:
    print(f'Error: File not found: $NETPLAN_CONFIG', file=sys.stderr)
    sys.exit(1)

def set_cloudflare_dns_addresses(conf):
    modified = False
    if isinstance(conf, dict):

        for key, value in conf.items():

            if key in ('ethernets', 'wifis', 'bridges', 'bonds', 'vlans') and isinstance(value, dict):
                for iface, iface_config in value.items():

                    if isinstance(iface_config, dict):


                        if 'nameservers' in iface_config and isinstance(iface_config['nameservers'], dict):

                            iface_config['nameservers']['addresses'] = ['1.1.1.1', '8.8.8.8']
                            modified = True






    return modified

if config and 'network' in config:
    network_section = config.get('network', {})
    if isinstance(network_section, dict):

        if set_cloudflare_dns_addresses(network_section):

            try:
                output = io.StringIO()
                yaml.dump(config, output, default_flow_style=False, indent=4, sort_keys=False, width=float('inf'))
                print(output.getvalue()) # Print YAML to stdout
                sys.exit(0) # Success
            except Exception as e:
                 print(f'Error dumping YAML: {e}', file=sys.stderr)
                 sys.exit(1)
        else:

            print('Warning: No existing "nameservers" sections found to modify in the config.', file=sys.stderr)


            sys.exit(1)
    elif not isinstance(network_section, dict):
        print(f'Error: Expected "network" section to be a dictionary, but got {type(network_section)}', file=sys.stderr)
        sys.exit(1)
else:
    print('Invalid or empty network configuration format (missing "network" key?).', file=sys.stderr)
    sys.exit(1)
")

    PYTHON_EXIT_CODE=$?
    if [ $PYTHON_EXIT_CODE -ne 0 ]; then

        if [ $PYTHON_EXIT_CODE -eq 1 ]; then
             echo "Python script indicated no modifications were needed (no existing 'nameservers' found)."


             rm -f "$BACKUP_FILE"
             echo "No changes applied to $NETPLAN_CONFIG."
             exit 0 # Exit cleanly as no error occurred, just nothing to do.
        else

            echo "Failed to process configuration using Python (Exit code: $PYTHON_EXIT_CODE)."
            echo "Check Python error messages above."
            echo "Restoring backup."
            if [ -f "$BACKUP_FILE" ]; then
                 sudo cp "$BACKUP_FILE" "$NETPLAN_CONFIG"
            else
                 echo "Error: Backup file $BACKUP_FILE not found!"
            fi
            exit 1 # Exit with error
        fi
    elif [ -z "$MODIFIED_YAML" ]; then

         echo "Python script produced empty output unexpectedly. Aborting."
         echo "Restoring backup."
         if [ -f "$BACKUP_FILE" ]; then
             sudo cp "$BACKUP_FILE" "$NETPLAN_CONFIG"
         else
             echo "Error: Backup file $BACKUP_FILE not found!"
         fi
         exit 1
    fi


    echo "Writing updated configuration to $NETPLAN_CONFIG..."
    TMP_FILE=$(mktemp)
    echo "$COMMENT_HEADER" > "$TMP_FILE"
    echo "$MODIFIED_YAML" >> "$TMP_FILE"

    if sudo mv "$TMP_FILE" "$NETPLAN_CONFIG"; then
        sudo chmod 644 "$NETPLAN_CONFIG"
        echo "Updated Netplan configuration content written."
    else
        echo "Error: Failed to move temporary file to $NETPLAN_CONFIG."
        rm -f "$TMP_FILE"
        echo "Restoring backup."
        if [ -f "$BACKUP_FILE" ]; then
            sudo cp "$BACKUP_FILE" "$NETPLAN_CONFIG"
        else
            echo "Error: Backup file $BACKUP_FILE not found!"
        fi
        exit 1
    fi

fi # End of handling existing vs new file



if [ -n "$MODIFIED_YAML" ] || [ -z "$BACKUP_FILE" ]; then

    echo "Validating Netplan configuration..."
    if ! sudo netplan try --timeout 30; then
        echo "-------------------------------------------"
        echo "ERROR: Netplan validation failed ('netplan try')."
        echo "The configuration in $NETPLAN_CONFIG is invalid."
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
           echo "Restoring backup from $BACKUP_FILE..."
           sudo cp "$BACKUP_FILE" "$NETPLAN_CONFIG"
           echo "Applying the restored configuration..."
           if sudo netplan apply; then
               echo "Successfully restored and applied backup."
           else
               echo "ERROR applying the restored backup configuration. Manual intervention required."
           fi
        else
           echo "No backup file available to restore (or new file was created). Manual intervention required."
           echo "The invalid configuration is in $NETPLAN_CONFIG."
        fi
        echo "-------------------------------------------"
        exit 1
    fi

    echo "Netplan configuration appears valid."
    echo "Applying final Netplan configuration..."
    if ! sudo netplan apply; then
        echo "-------------------------------------------"
        echo "ERROR: Failed to apply Netplan configuration ('netplan apply')."
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
            echo "Attempting to restore backup from $BACKUP_FILE..."
            sudo cp "$BACKUP_FILE" "$NETPLAN_CONFIG"
            echo "Applying the restored configuration..."
            if sudo netplan apply; then
               echo "Successfully restored and applied backup."
            else
               echo "ERROR applying the restored backup configuration. Manual intervention required."
            fi
        else
            echo "No backup file available to restore. Manual intervention required."
        fi
        echo "-------------------------------------------"
        exit 1
    fi

    echo "Cloudflare DNS configuration has been successfully applied!"
    echo "Your system should now be using Cloudflare DNS (1.1.1.1 and 8.8.8.8) where applicable."

    echo "Verifying DNS configuration..."
    sleep 2
    if command -v resolvectl &> /dev/null; then
        resolvectl status | grep "DNS Servers"
    elif command -v systemd-resolve &> /dev/null; then
        systemd-resolve --status | grep "DNS Servers"
    else
        echo "Could not find resolvectl or systemd-resolve to verify DNS settings."
    fi

else

    echo "No changes were made to the configuration file."
fi

exit 0
fi
