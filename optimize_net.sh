#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "❌ Please run as root"
  exit 1
fi

NUM_CPUS=$(nproc)
if [ "$NUM_CPUS" -le 1 ]; then
    echo "⚠️ Only 1 CPU detected. Cannot isolate cores."
    exit 1
fi

echo "🔍 Measuring network interrupt activity (NET_RX) per CPU for 2 seconds..."

read -a rx1 <<< $(grep "NET_RX:" /proc/softirqs | sed 's/NET_RX://')
sleep 2
read -a rx2 <<< $(grep "NET_RX:" /proc/softirqs | sed 's/NET_RX://')

MAX_DELTA=0
deltas=()

# مرحله اول: محاسبه ترافیک هر هسته و پیدا کردن بیشترین مقدار
for i in $(seq 0 $((${#rx1[@]} - 1))); do
    delta=$((rx2[i] - rx1[i]))
    deltas[$i]=$delta
    if [ "$delta" -gt "$MAX_DELTA" ]; then
        MAX_DELTA=$delta
    fi
done

if [ "$MAX_DELTA" -eq 0 ]; then
    echo "❌ No network activity detected. Exiting."
    exit 1
fi

# تعیین یک آستانه هوشمند (هر هسته‌ای که بیشتر از 15% بیشترین ترافیک را داشته باشد، هسته شبکه محسوب می‌شود)
THRESHOLD=$((MAX_DELTA * 15 / 100))

ALLOWED_CPUS=""
BUSY_CORES=""

# مرحله دوم: جداسازی هسته‌های شبکه از هسته‌های پردازشی
for i in $(seq 0 $((NUM_CPUS - 1))); do
    if [ "${deltas[$i]}" -gt "$THRESHOLD" ]; then
        if [ -z "$BUSY_CORES" ]; then BUSY_CORES="$i"; else BUSY_CORES="$BUSY_CORES, $i"; fi
    else
        if [ -z "$ALLOWED_CPUS" ]; then ALLOWED_CPUS="$i"; else ALLOWED_CPUS="$ALLOWED_CPUS,$i"; fi
    fi
done

echo "✅ Network Cores Detected: [$BUSY_CORES]"
echo "⚙️  Target cpuset for Docker: $ALLOWED_CPUS"

CONTAINERS=$(docker ps -q)
if [ -z "$CONTAINERS" ]; then
    echo "⚠️ No running Docker containers found."
    exit 0
fi

echo "🚀 Updating running containers..."
for container in $CONTAINERS; do
    NAME=$(docker inspect --format="{{.Name}}" $container | sed 's/\///')
    if docker update --cpuset-cpus="$ALLOWED_CPUS" "$container" > /dev/null 2>&1; then
        echo "   [SUCCESS] Container '$NAME' pinned to CPUs $ALLOWED_CPUS"
    else
        echo "   [FAILED] Could not update '$NAME'"
    fi
done

echo "🎉 All done!"
