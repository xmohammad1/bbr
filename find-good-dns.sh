#!/bin/bash

# Check for bash version (associative arrays need 4.0+)
if (( BASH_VERSINFO[0] < 4 )); then
    echo "Error: This script requires bash version 4.0 or higher for associative arrays." >&2
    exit 1
fi
# Initialize IPv6-only flag
ipv6_only=false

# Parse command-line arguments for --AAAA
for arg in "$@"; do
    if [[ "$arg" == "--AAAA" ]]; then
        ipv6_only=true
        break
    fi
done
dns_servers=(
    # Google Public DNS
    "8.8.8.8"
    "8.8.4.4"
    # Cloudflare
    "1.1.1.1"
    "1.0.0.1"
    # Quad9
    "9.9.9.9"
    "9.9.9.10"
    # Hetzner
    "185.12.64.1"
    "185.12.64.2"
    # OVH
    "213.186.33.99"
    # DNSPod Public DNS+ (Tencent)
    "119.29.29.29"
    "119.28.28.28"
    # NTT
    "129.250.35.250"
    "129.250.35.251"
    # AliDNS (Alibaba)
    "223.5.5.5"
    "223.6.6.6"
    # NextDNS
    "45.90.28.167"
    "45.90.30.167"
    # Cisco OpenDNS
    "208.67.222.222"
    "208.67.220.220"
    # Cisco OpenDNS Family Shield
    "208.67.222.123"
    "208.67.220.123"
    # Gcore
    "95.85.95.85"
    "2.56.220.2"
    # Level 3 / CenturyLink
    "4.2.2.1"
    "4.2.2.2"
    "4.2.2.3"
    "4.2.2.4"
    "4.2.2.5"
    "4.2.2.6"
    "209.244.0.3"
    "209.244.0.4"
    # AdGuard DNS
    "94.140.14.14"
    "94.140.15.15"
    # Control D
    "76.76.2.0"
    "76.76.10.0"
    # CleanBrowsing
    "185.228.168.9"
    "185.228.169.9"
    "185.228.168.168"
    "185.228.169.168"
    # Dyn DNS
    "216.146.35.35"
    "216.146.36.36"
    # Yandex DNS
    "77.88.8.8"
    "77.88.8.1"
    "77.88.8.88"
    "77.88.8.2"
    # Hurricane Electric
    "74.82.42.42"
    # Quad9 (Additional servers)
    "149.112.121.10"
    "149.112.122.10"
    # Comodo Secure DNS
    "8.26.56.26"
    "8.20.247.20"
    # Qwest/CenturyLink
    "205.171.3.65"
    "205.171.2.65"
    # Verisign Public DNS
    "64.6.64.6"
    "64.6.65.6"
    # Neustar Security Services (UltraDNS Public)
    "156.154.70.1"
    "156.154.71.1"
    "156.154.70.5"
    # SafeDNS
    "195.46.39.39"
    "195.46.39.40"
    # dnsforge.de
    "176.9.93.198"
    "176.9.1.117"
    # Notron
    "199.85.126.10"
    "199.85.127.10"
)

target_host="google.com"
ping_count=3 # Number of pings per server
ping_timeout=1
dig_timeout=2
dig_tries=1
dig_repeat=3  # How many times to measure DNS query time for averaging

# --- Check Dependencies ---
command -v dig >/dev/null 2>&1 || { echo >&2 "Error: 'dig' command not found. Please install dnsutils or bind-utils."; exit 1; }
command -v ping >/dev/null 2>&1 || { echo >&2 "Error: 'ping' command not found. Usually part of iputils or similar."; exit 1; }
command -v time >/dev/null 2>&1 || { echo >&2 "Error: 'time' command not found. Usually part of coreutils."; exit 1; }
command -v head >/dev/null 2>&1 || { echo >&2 "Error: 'head' command not found. Usually part of coreutils."; exit 1; }
command -v awk >/dev/null 2>&1 || { echo >&2 "Error: 'awk' command not found."; exit 1; }
command -v sort >/dev/null 2>&1 || { echo >&2 "Error: 'sort' command not found."; exit 1; }
command -v grep >/dev/null 2>&1 || { echo >&2 "Error: 'grep' command not found."; exit 1; }


# --- Storage for Results ---
declare -A ping_results     # Key = DNS IP, Value = Average Ping Time (ms)
declare -A query_results    # Key = DNS IP, Value = Average Query Time (ms)
declare -A combined_results # Key = DNS IP, Value = Combined Score (weighted average)

# --- Function to Extract Average Ping ---
extract_avg_ping() {
    local output="$1"
    # Look for the summary line (formats vary slightly across ping versions)
    local avg_ping=$(echo "$output" | grep -oE '[=/][0-9]+\.[0-9]+/[0-9]+\.[0-9]+/[0-9]+\.[0-9]+' | cut -d '/' -f 3)

    # Fallback for simpler formats or if the above fails
    if [[ -z "$avg_ping" ]]; then
       avg_ping=$(echo "$output" | grep 'avg' | awk -F '/' '{print $}')
    fi

    # Ensure it's a number (basic check)
    if [[ "$avg_ping" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$avg_ping"
    else
        echo "" # Return empty if extraction failed
    fi
}

# --- Function to Measure DNS Query Time ---
measure_dns_query_time() {
    local dns_ip="$1"
    local target="$2"
    local total_time=0
    local successful_queries=0
    
    for ((i=1; i<=dig_repeat; i++)); do
        # Use dig's built-in query time reporting (+stats)
        local query_output=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target" A +stats)
        local query_status=$?
        
        if [[ $query_status -eq 0 ]]; then
            # Extract query time from dig output (in milliseconds)
            local query_time=$(echo "$query_output" | grep "Query time:" | awk '{print $4}')
            if [[ -n "$query_time" && "$query_time" =~ ^[0-9]+$ ]]; then
                total_time=$((total_time + query_time))
                ((successful_queries++))
            fi
        fi
    done
    
    # Calculate average if any successful queries
    if [[ $successful_queries -gt 0 ]]; then
        echo $((total_time / successful_queries))
    else
        echo ""
    fi
}

# --- Main Loop ---
echo "Testing DNS resolution speed and ping latency for $target_host..."
echo "Using $ping_count pings with a ${ping_timeout}s timeout per ping."
echo "Using dig with a ${dig_timeout}s timeout and ${dig_tries} tries."
echo "DNS query time will be measured $dig_repeat times per server."
echo "--------------------------------------------------"

for dns_ip in "${dns_servers[@]}"; do
    echo -n "Testing DNS Server: $dns_ip ... "

    # Measure DNS query time first
    query_time=$(measure_dns_query_time "$dns_ip" "$target_host")
    
    if [[ -n "$query_time" ]]; then
        echo -n "Query time: ${query_time}ms ... "
        query_results["$dns_ip"]=$query_time
        
        # Now resolve IP for pinging
        resolved_ip=""
        ping_cmd="ping" # Default to IPv4 ping

    if $ipv6_only; then
        # Only try AAAA records
        current_resolved_ip=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target_host" AAAA +short | head -n1)
        if [[ "$current_resolved_ip" == *":"* ]]; then
            resolved_ip=$current_resolved_ip
            if command -v ping6 >/dev/null 2>&1; then
                ping_cmd="ping6"
                echo -n "Resolved AAAA ($resolved_ip) ... "
            else
                echo "ping6 not found, cannot ping IPv6 address."
                continue
            fi
        else
            echo "FAILED to resolve AAAA for '$target_host'"
            continue
        fi
    else
        # Try A first, then AAAA
        current_resolved_ip=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target_host" A +short | head -n1)
        if [[ "$current_resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            resolved_ip=$current_resolved_ip
            echo -n "Resolved A ($resolved_ip) ... "
        else
            current_resolved_ip=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target_host" AAAA +short | head -n1)
            if [[ "$current_resolved_ip" == *":"* ]]; then
                resolved_ip=$current_resolved_ip
                if command -v ping6 >/dev/null 2>&1; then
                    ping_cmd="ping6"
                    echo -n "Resolved AAAA ($resolved_ip) ... "
                else
                    echo "ping6 not found, cannot ping IPv6 address."
                    continue
                fi
            else
                echo "FAILED to resolve '$target_host'"
                continue
            fi
        fi
    fi

        # Proceed if we got a valid-looking IP
        if [[ -n "$resolved_ip" ]]; then
            # Ping the RESOLVED IP address, capture output and status
            ping_output=$("$ping_cmd" -c "$ping_count" -W "$ping_timeout" "$resolved_ip" 2>&1)
            ping_status=$?

            if [[ $ping_status -eq 0 ]]; then
                # Extract average ping time
                avg_ping=$(extract_avg_ping "$ping_output")

                if [[ -n "$avg_ping" ]]; then
                    ping_results["$dns_ip"]=$avg_ping
                    # Calculate combined score: sum of query time and ping time
                    combined_score=$(echo "scale=2; (1 * $query_time) + (1 * $avg_ping)" | bc)
                    combined_results["$dns_ip"]=$combined_score
                    echo "OK (Query: ${query_time}ms, Ping: ${avg_ping}ms, Combined: ${combined_score})"
                else
                    echo "Ping OK, but failed to extract avg time."
                fi
            else
                echo "Ping FAILED (Exit code: $ping_status)"
            fi
        else
            echo "FAILED to resolve '$target_host'"
        fi
    else
        echo "DNS query FAILED or timed out"
    fi
done

echo "--------------------------------------------------"
echo "Processing results..."

# --- Sort and Print Results Based on Ping Only ---
num_ping_results=${#ping_results[@]}

if [[ $num_ping_results -eq 0 ]]; then
    echo "No successful ping results were recorded."
else
    echo "Found $num_ping_results successful ping result(s)."
    echo "Top performers by Ping time only (DNS Server -> Ping Time):"

    # Sort the results numerically based on ping time only
    sorted_ping_results=$(
        for dns in "${!ping_results[@]}"; do
            echo "${ping_results[$dns]} $dns"
        done | sort -n
    )

    # Get the top 10 (or fewer if less than 10 results)
    top_ping_results=$(echo "$sorted_ping_results" | head -n 10)

    rank=1
    echo "$top_ping_results" | while read -r ping dns_server; do
        # Check if line is empty (can happen with head)
        if [[ -n "$ping" ]]; then
           query="${query_results[$dns_server]}"
           printf "%d. %s (Ping: %sms, Query: %sms)\n" "$rank" "$dns_server" "$ping" "$query"
           ((rank++))
        fi
    done
fi

echo "--------------------------------------------------"

# --- Sort and Print Results Based on Combined Score ---
num_results=${#combined_results[@]}

if [[ $num_results -eq 0 ]]; then
    echo "No successful combined results were recorded."
    exit 0
fi

echo "Found $num_results successful combined result(s)."
echo "Top performers by Combined Score (DNS Server -> Combined Score [Query + Ping]):"

# Sort the results numerically based on the combined score
sorted_results=$(
    for dns in "${!combined_results[@]}"; do
        echo "${combined_results[$dns]} $dns"
    done | sort -n
)

# Get the top 10 (or fewer if less than 10 results)
top_results=$(echo "$sorted_results" | head -n 10)

rank=1
echo "$top_results" | while read -r score dns_server; do
    # Check if line is empty (can happen with head)
    if [[ -n "$score" ]]; then
       query="${query_results[$dns_server]}"
       ping="${ping_results[$dns_server]}"
       printf "%d. %s (Query: %sms, Ping: %sms, Combined: %s)\n" "$rank" "$dns_server" "$query" "$ping" "$score"
       ((rank++))
    fi
done

echo "--------------------------------------------------"
echo "DNS test complete."
