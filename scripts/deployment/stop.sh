#!/bin/bash

# Stop Mushroom Substrate Monitor services

echo "🛑 Stopping Mushroom Substrate Monitor services..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to kill process by PID file
kill_by_pidfile() {
    local service=$1
    local pidfile=$2
    
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 $pid 2>/dev/null; then
            echo "Stopping $service (PID: $pid)..."
            kill $pid
            sleep 2
            if kill -0 $pid 2>/dev/null; then
                echo -e "${RED}Force stopping $service...${NC}"
                kill -9 $pid
            fi
            rm -f "$pidfile"
            echo -e "${GREEN}$service stopped${NC}"
        else
            echo "$service was not running"
            rm -f "$pidfile"
        fi
    else
        echo "$service PID file not found"
    fi
}

# Stop backend
kill_by_pidfile "Backend" "backend.pid"

# Stop dashboard
kill_by_pidfile "Dashboard" "dashboard.pid"

echo "✅ All services stopped"
