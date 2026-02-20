#!/bin/bash

# Mushroom Substrate Monitor Deployment Script
# Deploys the complete system

set -e  # Exit on error

echo "🚀 Deploying Mushroom Substrate Monitor..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root is not recommended. Continuing anyway..."
fi

# Check for required commands
check_commands() {
    local commands=("python3" "pip" "git" "docker" "docker-compose")
    
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd is not installed. Please install it first."
            exit 1
        fi
    done
    print_info "All required commands are available"
}

# Setup Python virtual environments
setup_python() {
    print_info "Setting up Python environments..."
    
    # Backend
    if [ ! -d "backend/venv" ]; then
        print_info "Creating backend virtual environment..."
        cd backend
        python3 -m venv venv
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        deactivate
        cd ..
    fi
    
    # Dashboard
    if [ ! -d "dashboard/venv" ]; then
        print_info "Creating dashboard virtual environment..."
        cd dashboard
        python3 -m venv venv
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        deactivate
        cd ..
    fi
    
    print_info "Python environments setup complete"
}

# Setup database
setup_database() {
    print_info "Setting up database..."
    
    # Create data directory if it doesn't exist
    mkdir -p data
    
    # Initialize SQLite database
    if [ ! -f "data/mushroom.db" ]; then
        print_info "Creating SQLite database..."
        sqlite3 data/mushroom.db "SELECT 'Database created successfully';"
    fi
    
    # Run database migrations
    print_info "Running database migrations..."
    cd backend
    source venv/bin/activate
    python -c "
from app.core.database import engine, Base
import asyncio
import app.models.sensor_data
import app.models.actuator_log
import app.models.alert

async def create_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print('Database tables created')

asyncio.run(create_tables())
"
    deactivate
    cd ..
    
    print_info "Database setup complete"
}

# Build and upload firmware
deploy_firmware() {
    print_info "Deploying firmware to ESP32..."
    
    if [ ! -d "firmware" ]; then
        print_error "Firmware directory not found"
        return 1
    fi
    
    cd firmware
    
    # Check if PlatformIO is installed
    if ! command -v pio &> /dev/null; then
        print_warning "PlatformIO not found. Installing..."
        pip install platformio
    fi
    
    # Build firmware
    print_info "Building firmware..."
    pio run
    
    # Ask for ESP32 port
    read -p "Enter ESP32 port (e.g., /dev/ttyUSB0 or COM3): " port
    
    if [ -z "$port" ]; then
        print_warning "No port specified. Skipping firmware upload."
    else
        print_info "Uploading firmware to $port..."
        pio run --target upload --upload-port $port
        
        print_info "Uploading web files to SPIFFS..."
        pio run --target uploadfs --upload-port $port
    fi
    
    cd ..
    print_info "Firmware deployment complete"
}

# Start backend server
start_backend() {
    print_info "Starting backend server..."
    
    cd backend
    source venv/bin/activate
    
    # Run in background
    nohup python -m app.main > ../logs/backend.log 2>&1 &
    BACKEND_PID=$!
    
    # Save PID to file
    echo $BACKEND_PID > ../backend.pid
    
    deactivate
    cd ..
    
    sleep 3  # Wait for server to start
    
    # Check if server is running
    if curl -s http://localhost:8000/health > /dev/null; then
        print_info "Backend server started successfully (PID: $BACKEND_PID)"
    else
        print_error "Backend server failed to start"
        return 1
    fi
}

# Start dashboard
start_dashboard() {
    print_info "Starting dashboard..."
    
    cd dashboard
    source venv/bin/activate
    
    # Run in background
    nohup streamlit run streamlit_app.py > ../logs/dashboard.log 2>&1 &
    DASHBOARD_PID=$!
    
    # Save PID to file
    echo $DASHBOARD_PID > ../dashboard.pid
    
    deactivate
    cd ..
    
    sleep 5  # Wait for dashboard to start
    
    # Check if dashboard is running
    if curl -s http://localhost:8501 > /dev/null; then
        print_info "Dashboard started successfully (PID: $DASHBOARD_PID)"
    else
        print_error "Dashboard failed to start"
        return 1
    fi
}

# Display deployment information
display_info() {
    echo ""
    echo "================================================"
    echo "           DEPLOYMENT COMPLETE!"
    echo "================================================"
    echo ""
    echo "🌐 Services:"
    echo "   Backend API:    http://localhost:8000"
    echo "   API Docs:       http://localhost:8000/api/docs"
    echo "   Dashboard:      http://localhost:8501"
    echo ""
    echo "📁 Directories:"
    echo "   Logs:           ./logs/"
    echo "   Data:           ./data/"
    echo "   Config:         ./config/"
    echo ""
    echo "⚙️ Management:"
    echo "   View logs:      tail -f logs/backend.log"
    echo "   Stop all:       ./scripts/deployment/stop.sh"
    echo "   Restart:        ./scripts/deployment/restart.sh"
    echo ""
    echo "🔧 Next steps:"
    echo "   1. Update WiFi credentials in firmware/include/config.h"
    echo "   2. Upload firmware to ESP32"
    echo "   3. Access ESP32 dashboard at http://[ESP32_IP]/"
    echo "   4. Configure alerts in config/system/system_config.yaml"
    echo ""
    echo "For help, check the documentation in docs/"
    echo "================================================"
}

# Main deployment function
main() {
    echo "================================================"
    echo "  Mushroom Substrate Monitor Deployment"
    echo "================================================"
    echo ""
    
    # Check commands
    check_commands
    
    # Setup Python environments
    setup_python
    
    # Setup database
    setup_database
    
    # Create logs directory
    mkdir -p logs
    
    # Ask about firmware deployment
    read -p "Do you want to deploy firmware to ESP32? (y/n): " deploy_firmware_choice
    if [[ $deploy_firmware_choice =~ ^[Yy]$ ]]; then
        deploy_firmware
    fi
    
    # Start services
    start_backend
    start_dashboard
    
    # Display deployment info
    display_info
    
    print_info "Deployment completed successfully!"
}

# Run main function
main
