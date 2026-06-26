#!/bin/bash

LOG_FILE="../logs/monitor.log"
PORT="15034"

echo "===== Agent Monitor ====="

PID=$(pgrep -f "agent-leak-app" | head -n 1)

if [ -n "$PID" ]; then
    echo "[OK] Agent is running (PID: $PID)"
else
    echo "[FAIL] Agent process not found"
    exit 1
fi

if ss -tuln | grep -q ":$PORT"; then
    echo "[OK] Port $PORT listening"
else
    echo "[FAIL] Port $PORT not listening"
    exit 1
fi

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
MEM=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
DISK=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

echo "CPU Usage : ${CPU}%"
echo "MEM Usage : ${MEM}%"
echo "DISK Used : ${DISK}%"

NOW=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$NOW] PID:$PID CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK}%" >> "$LOG_FILE"

echo "[INFO] monitor completed"
