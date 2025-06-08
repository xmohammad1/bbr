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
    "149.112.112.112"
    # Cisco OpenDNS
    "208.67.222.222"
    "208.67.220.220"
    # DNSPod Public DNS+ (Tencent)
    "119.29.29.29"
    "119.28.28.28"
    # NTT
    "129.250.35.250"
    "129.250.35.251"
    # NextDNS
    "45.90.28.167"
    "45.90.30.167"
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
    # Control D
    "76.76.2.0"
    "76.76.10.0"
    # Comodo Secure DNS
    "8.26.56.26"
    "8.20.247.20"
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

# --- NEW: Array of target hosts ---
target_hosts_array=(
    "google.com"
    "instagram.com"
    "www.gstatic.com"
)

ping_count=2 # Number of pings per server per target host
ping_timeout=1
dig_timeout=2
dig_tries=1
dig_repeat=2  # How many times to measure DNS query time for averaging per target

# --- Check Dependencies ---
command -v dig >/dev/null 2>&1 || { echo >&2 "Error: 'dig' command not found. Please install dnsutils or bind-utils."; exit 1; }
command -v ping >/dev/null 2>&1 || { echo >&2 "Error: 'ping' command not found. Usually part of iputils or similar."; exit 1; }
command -v time >/dev/null 2>&1 || { echo >&2 "Error: 'time' command not found. Usually part of coreutils."; exit 1; }
command -v head >/dev/null 2>&1 || { echo >&2 "Error: 'head' command not found. Usually part of coreutils."; exit 1; }
command -v awk >/dev/null 2>&1 || { echo >&2 "Error: 'awk' command not found."; exit 1; }
command -v sort >/dev/null 2>&1 || { echo >&2 "Error: 'sort' command not found."; exit 1; }
command -v grep >/dev/null 2>&1 || { echo >&2 "Error: 'grep' command not found."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo >&2 "Error: 'bc' command not found. Please install bc."; exit 1; }


# --- Storage for Results ---
declare -A ping_results     # Key = DNS IP, Value = Average Ping Time (ms) across all targets
declare -A query_results    # Key = DNS IP, Value = Average Query Time (ms) across all targets
declare -A combined_results # Key = DNS IP, Value = Combined Score (weighted average) across all targets

# --- Function to Extract Average Ping ---
extract_avg_ping() {
    local output="$1"
    local avg_ping=$(echo "$output" | grep -oE '[=/][0-9\.]+/[0-9\.]+/[0-9\.]+/[0-9\.]+' | head -n1 | cut -d '/' -f 3)
    if [[ -z "$avg_ping" ]]; then
       avg_ping=$(echo "$output" | grep 'avg' | awk -F'/' '{print $5}' | awk -F' ' '{print $1}') # More generic avg attempt
    fi
    if [[ "$avg_ping" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$avg_ping"
    else
        echo ""
    fi
}

# --- Function to Measure DNS Query Time ---
measure_dns_query_time() {
    local dns_ip="$1"
    local target="$2"
    local total_time_ms=0
    local successful_queries=0

    for ((i=1; i<=dig_repeat; i++)); do
        local query_output=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target" A +stats 2>/dev/null)
        local query_status=$?

        if [[ $query_status -eq 0 ]]; then
            local query_time=$(echo "$query_output" | grep "Query time:" | awk '{print $4}')
            if [[ -n "$query_time" && "$query_time" =~ ^[0-9]+$ ]]; then # dig reports in ms
                total_time_ms=$((total_time_ms + query_time))
                ((successful_queries++))
            fi
        fi
         # Add a small delay between repeated digs to the same server for the same host
        sleep 0.1
    done

    if [[ $successful_queries -gt 0 ]]; then
        echo $((total_time_ms / successful_queries))
    else
        echo ""
    fi
}

# --- Main Loop ---
echo "Testing DNS resolution speed and ping latency for multiple target hosts..."
echo "Targets: ${target_hosts_array[*]}"
echo "Using $ping_count pings with a ${ping_timeout}s timeout per ping per target."
echo "Using dig with a ${dig_timeout}s timeout and ${dig_tries} tries per target."
echo "DNS query time will be measured $dig_repeat times per server per target."
echo "--------------------------------------------------------------------------"

for dns_ip in "${dns_servers[@]}"; do
    echo "Testing DNS Server: $dns_ip"

    # Accumulators for this DNS server across all targets
    total_query_time_for_dns_server=0
    successful_queries_count_for_dns_server=0
    total_ping_time_for_dns_server=0
    successful_pings_count_for_dns_server=0

    for target_host in "${target_hosts_array[@]}"; do
        echo -n "  Target: $target_host ... "

        # Measure DNS query time for this target
        current_query_time=$(measure_dns_query_time "$dns_ip" "$target_host")

        if [[ -n "$current_query_time" ]]; then
            total_query_time_for_dns_server=$(echo "$total_query_time_for_dns_server + $current_query_time" | bc)
            ((successful_queries_count_for_dns_server++))
            echo -n "Query: ${current_query_time}ms ... "

            resolved_ip=""
            ping_cmd="ping" # Default to IPv4 ping

            if $ipv6_only; then
                current_resolved_ip=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target_host" AAAA +short | head -n1)
                if [[ "$current_resolved_ip" == *":"* ]]; then # Basic IPv6 check
                    resolved_ip=$current_resolved_ip
                    if command -v ping6 >/dev/null 2>&1; then
                        ping_cmd="ping6"
                        echo -n "Resolved AAAA ($resolved_ip) ... "
                    else
                        echo "ping6 not found, cannot ping IPv6 address for $target_host."
                        resolved_ip="" # Mark as unresolved for this target
                    fi
                else
                    echo "FAILED to resolve AAAA for '$target_host'"
                    resolved_ip=""
                fi
            else
                # Try A first
                current_resolved_ip=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target_host" A +short | head -n1)
                if [[ "$current_resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    resolved_ip=$current_resolved_ip
                    echo -n "Resolved A ($resolved_ip) ... "
                else # Try AAAA if A failed or was not IPv4
                    current_resolved_ip=$(dig "+time=$dig_timeout" "+tries=$dig_tries" "@$dns_ip" "$target_host" AAAA +short | head -n1)
                    if [[ "$current_resolved_ip" == *":"* ]]; then
                        resolved_ip=$current_resolved_ip
                        if command -v ping6 >/dev/null 2>&1; then
                            ping_cmd="ping6"
                            echo -n "Resolved AAAA ($resolved_ip) ... "
                        else
                            echo "ping6 not found, cannot ping IPv6 address for $target_host."
                            resolved_ip=""
                        fi
                    else
                        echo "FAILED to resolve A or AAAA for '$target_host'"
                        resolved_ip=""
                    fi
                fi
            fi

            if [[ -n "$resolved_ip" ]]; then
                ping_output=$("$ping_cmd" -c "$ping_count" -W "$ping_timeout" "$resolved_ip" 2>&1)
                ping_status=$?

                if [[ $ping_status -eq 0 ]]; then
                    avg_ping=$(extract_avg_ping "$ping_output")
                    if [[ -n "$avg_ping" ]]; then
                        total_ping_time_for_dns_server=$(echo "$total_ping_time_for_dns_server + $avg_ping" | bc)
                        ((successful_pings_count_for_dns_server++))
                        echo "Ping: ${avg_ping}ms"
                    else
                        echo "Ping OK, but failed to extract avg time."
                    fi
                else
                    echo "Ping FAILED (Exit code: $ping_status)"
                fi
            fi
        else
            echo "DNS query FAILED or timed out for $target_host"
        fi
    done # End of target_host loop

    # Calculate and store averages for this DNS server
    avg_query_time_overall=""
    avg_ping_time_overall=""

    if (( successful_queries_count_for_dns_server > 0 )); then
        avg_query_time_overall=$(echo "scale=2; $total_query_time_for_dns_server / $successful_queries_count_for_dns_server" | bc)
        query_results["$dns_ip"]=$avg_query_time_overall
    fi

    if (( successful_pings_count_for_dns_server > 0 )); then
        avg_ping_time_overall=$(echo "scale=2; $total_ping_time_for_dns_server / $successful_pings_count_for_dns_server" | bc)
        ping_results["$dns_ip"]=$avg_ping_time_overall
    fi

    echo -n "  Summary for $dns_ip: "
    if [[ -n "$avg_query_time_overall" && -n "$avg_ping_time_overall" ]]; then
        combined_score=$(echo "scale=2; (1 * $avg_query_time_overall) + (1 * $avg_ping_time_overall)" | bc)
        combined_results["$dns_ip"]=$combined_score
        echo "Avg Query: ${avg_query_time_overall}ms, Avg Ping: ${avg_ping_time_overall}ms, Combined: ${combined_score}"
    elif [[ -n "$avg_query_time_overall" ]]; then
        echo "Avg Query: ${avg_query_time_overall}ms (Pings failed or insufficient data for all targets)"
    elif [[ -n "$avg_ping_time_overall" ]]; then
        echo "Avg Ping: ${avg_ping_time_overall}ms (Queries failed or insufficient data for all targets)"
    else
        echo "All tests failed (query/ping) for all targets."
    fi
    echo "--------------------------------------------------------------------------"
done # End of dns_ip loop

echo "Processing results..."

# --- Sort and Print Results Based on Ping Only ---
num_ping_results=${#ping_results[@]}

if [[ $num_ping_results -eq 0 ]]; then
    echo "No successful average ping results were recorded."
else
    echo "Found $num_ping_results DNS servers with successful average ping result(s)."
    echo "Top performers by Average Ping time only (DNS Server -> Avg Ping Time):"

    sorted_ping_results=$(
        for dns in "${!ping_results[@]}"; do
            echo "${ping_results[$dns]} $dns"
        done | sort -n
    )

    top_ping_results=$(echo "$sorted_ping_results" | head -n 10)
    rank=1
    echo "$top_ping_results" | while read -r ping dns_server; do
        if [[ -n "$ping" ]]; then
           query="${query_results[$dns_server]:-N/A}" # Display N/A if query data is missing
           printf "%d. %s (Avg Ping: %sms, Avg Query: %sms)\n" "$rank" "$dns_server" "$ping" "$query"
           ((rank++))
        fi
    done
fi

echo "--------------------------------------------------------------------------"

# --- Sort and Print Results Based on Combined Score ---
num_results=${#combined_results[@]}

if [[ $num_results -eq 0 ]]; then
    echo "No successful combined results were recorded (need both query and ping data)."
    exit 0
fi

echo "Found $num_results DNS servers with successful combined result(s)."
echo "Top performers by Combined Score (DNS Server -> Combined Score [Avg Query + Avg Ping]):"

sorted_results=$(
    for dns in "${!combined_results[@]}"; do
        echo "${combined_results[$dns]} $dns"
    done | sort -n
)

top_results=$(echo "$sorted_results" | head -n 10)
rank=1
echo "$top_results" | while read -r score dns_server; do
    if [[ -n "$score" ]]; then
       query="${query_results[$dns_server]}"
       ping="${ping_results[$dns_server]}"
       printf "%d. %s (Avg Query: %sms, Avg Ping: %sms, Combined: %s)\n" "$rank" "$dns_server" "$query" "$ping" "$score"
       ((rank++))
    fi
done

echo "--------------------------------------------------------------------------"
echo "DNS test complete."
