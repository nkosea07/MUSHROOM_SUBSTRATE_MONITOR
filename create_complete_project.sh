
cat > PROJECT_PLAN.md << 'EOF'
# Project Timeline and Milestones

## 📅 Overall Timeline
- **Start Date:** February 1, 2026
- **MVP Deadline:** February 28, 2026
- **Complete System:** March 31, 2026
- **Final Submission:** April 30, 2026

## 🎯 Phase 1: MVP Development (February 2026)

### Week 1-2: Core Infrastructure (Feb 1-14)
**Objectives:**
- [x] ESP32 firmware for temperature monitoring
- [x] Basic HTTP API endpoints
- [x] Streamlit dashboard framework
- [x] Database schema design
- [x] Hardware wiring and testing

**Deliverables:**
- Working temperature sensor
- Basic web dashboard
- Data logging to SQLite
- Project documentation structure

### Week 3-4: Control System (Feb 15-28)
**Objectives:**
- [ ] Moisture sensor integration
- [ ] Automatic control logic
- [ ] Manual override functionality
- [ ] Enhanced dashboard
- [ ] Basic alert system

**Deliverables:**
- Complete MVP with temperature + moisture
- Automatic fan/heater control
- Functional web interface
- MVP demonstration ready

## 🚀 Phase 2: Complete System (March 2026)

### Week 5-6: pH System Integration (Mar 1-14)
**Objectives:**
- [ ] pH sensor calibration and integration
- [ ] Dual-pump control system
- [ ] Enhanced control algorithms
- [ ] Advanced data validation
- [ ] Backend API completion

**Deliverables:**
- All three sensors working
- pH adjustment system
- Complete backend API
- Enhanced dashboard

### Week 7-8: Enhanced Features (Mar 15-28)
**Objectives:**
- [ ] Email/SMS notification system
- [ ] Advanced report generation
- [ ] Mobile app interface
- [ ] Data analytics dashboard
- [ ] System testing

**Deliverables:**
- Complete notification system
- PDF report generation
- Mobile-responsive interface
- Analytics dashboard

### Week 9-10: Testing & Optimization (Mar 29 - Apr 11)
**Objectives:**
- [ ] System integration testing
- [ ] Performance optimization
- [ ] Security implementation
- [ ] User acceptance testing
- [ ] Bug fixes and refinement

**Deliverables:**
- Fully tested system
- Performance metrics
- Security audit report
- User feedback incorporated

## ✨ Phase 3: Final Polish (April 2026)

### Week 11-12: Documentation (Apr 12-25)
**Objectives:**
- [ ] Complete user manual
- [ ] Technical documentation
- [ ] Academic project report
- [ ] Presentation materials
- [ ] Video demonstration

**Deliverables:**
- User manual (PDF)
- Technical documentation
- Final project report
- Presentation slides
- Demo video

### Week 13-14: Final Preparation (Apr 26-30)
**Objectives:**
- [ ] Live demo setup
- [ ] Performance tuning
- [ ] Backup and recovery
- [ ] Final submission
- [ ] Project presentation

**Deliverables:**
- Live demonstration
- Final code submission
- Complete documentation
- Project presentation
- Supervisor approval

## 📊 Milestone Deliverables

### February 28, 2026 (MVP)
- ✅ Working temperature monitoring
- ✅ Working moisture monitoring  
- ✅ Basic automatic control
- ✅ Functional dashboard
- ✅ Data logging system
- ✅ Basic alert system

### March 31, 2026 (Complete System)
- ✅ All sensors integrated (temp, moisture, pH)
- ✅ Complete automatic control system
- ✅ Advanced reporting features
- ✅ Mobile app interface
- ✅ Email/SMS notifications
- ✅ Analytics dashboard

### April 30, 2026 (Final Submission)
- ✅ Complete documentation
- ✅ Live demonstration
- ✅ Project presentation
- ✅ Final report submission
- ✅ Code repository
- ✅ Supervisor evaluation

## 🎯 Success Criteria

### Technical Success:
- All 5 project objectives demonstrated
- System operates 24/7 without crashes
- Data accuracy within ±5%
- Response time < 2 seconds
- User-friendly interface

### Academic Success:
- Complete project documentation
- Literature review and methodology
- Results analysis and discussion
- Proper citations and references
- Successful defense presentation

### User Success:
- Intuitive user interface
- Useful reports and alerts
- Easy system configuration
- Reliable performance
- Positive user feedback

## ⚠️ Risk Mitigation

### Technical Risks:
1. **Sensor inaccuracy:** Regular calibration, multiple sensors
2. **WiFi connectivity:** Auto-reconnect, AP fallback mode
3. **Power failure:** Battery backup, state recovery
4. **Hardware failure:** Redundant components, manual override

### Timeline Risks:
1. **Component delays:** Order early, have alternatives
2. **Technical challenges:** Weekly progress reviews
3. **Scope creep:** Stick to MVP, add features later
4. **Testing issues:** Start testing early, iterative approach

### Resource Risks:
1. **Budget constraints:** Use affordable components
2. **Time constraints:** Focus on core features first
3. **Technical expertise:** Use proven libraries, seek help
4. **Equipment availability:** Book lab equipment in advance

## 📈 Progress Tracking

### Weekly Checkpoints:
1. **Monday:** Plan week objectives
2. **Wednesday:** Mid-week progress review
3. **Friday:** Complete weekly deliverables
4. **Sunday:** Prepare for next week

### Documentation:
- Daily development log
- Weekly progress reports
- Issue and bug tracking
- Testing results
- User feedback

### Version Control:
- Git for all code
- Semantic versioning
- Branch per feature
- Regular commits
- Code reviews
EOF

# ========== CREATE SCRIPT FILES ==========
echo "📜 Creating script files..."

# Deployment script
cat > scripts/deployment/deploy.sh << 'EOF'
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
EOF

chmod +x scripts/deployment/deploy.sh

# Stop script
cat > scripts/deployment/stop.sh << 'EOF'
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
EOF

chmod +x scripts/deployment/stop.sh

# ========== CREATE FINAL STRUCTURE SUMMARY ==========
echo "📋 Creating final structure files..."

# Create .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual Environment
venv/
env/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Database
*.db
*.sqlite
*.sqlite3

# Logs
*.log
logs/

# Data
data/raw/
data/processed/
data/reports/
data/backups/

# Secrets
*.pem
*.key
*.crt
secrets.json
config/secrets.yaml
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Docker
docker-compose.override.yml

# Temporary files
tmp/
temp/

# Project specific
firmware/.pio/
firmware/build/
hardware/__pycache__/
backend/__pycache__/
dashboard/__pycache__/

# PlatformIO
firmware/.pio/
firmware/build/

# Uploads
uploads/

# PID files
*.pid

# Test coverage
.coverage
htmlcov/

# Jupyter
.ipynb_checkpoints

# VS Code
.vscode/settings.json
.vscode/launch.json
EOF

# Create LICENSE
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 Taboka Wandile Thenga

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Create .env.example
cat > .env.example << 'EOF'
# Environment
ENVIRONMENT=development
DEBUG=True

# Server
HOST=0.0.0.0
PORT=8000

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8501

# Database
DATABASE_URL=sqlite:///./mushroom.db
# For PostgreSQL: postgresql://user:password@localhost/mushroom

# Redis
REDIS_URL=redis://localhost:6379

# InfluxDB (optional)
INFLUXDB_URL=http://localhost:8086
INFLUXDB_TOKEN=your-token-here
INFLUXDB_ORG=mushroom
INFLUXDB_BUCKET=sensor_data

# ESP32
ESP32_BASE_URL=http://192.168.1.100
ESP32_TIMEOUT=10

# Security
SECRET_KEY=your-secret-key-change-in-production

# Email (optional)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# File Uploads
UPLOAD_DIR=./uploads
MAX_UPLOAD_SIZE=10485760

# Logging
LOG_LEVEL=INFO
METRICS_ENABLED=True

# Sensor Thresholds
TEMPERATURE_MIN=22.0
TEMPERATURE_MAX=26.0
MOISTURE_MIN=60.0
MOISTURE_MAX=70.0
PH_MIN=6.5
PH_MAX=7.0
EOF

echo ""
echo "================================================"
echo "✅ COMPLETE PROJECT STRUCTURE CREATED!"
echo "================================================"
echo ""
echo "📁 Project Structure Summary:"
echo ""
echo "MUSHROOM_SUBSTRATE_MONITOR/"
echo "├── 📁 firmware/                     # ESP32 Arduino/PlatformIO Code"
echo "│   ├── src/                        # Source files"
echo "│   ├── include/                    # Header files"
echo "│   ├── data/                       # Web dashboard files"
echo "│   └── test/                       # Unit tests"
echo "│"
echo "├── 📁 backend/                     # Python FastAPI Backend"
echo "│   ├── app/                        # Application code"
echo "│   │   ├── api/                    # API endpoints"
echo "│   │   ├── core/                   # Core modules"
echo "│   │   ├── crud/                   # Database operations"
echo "│   │   ├── models/                 # Database models"
echo "│   │   ├── services/               # Business logic"
echo "│   │   └── utils/                  # Utilities"
echo "│   ├── tests/                      # Backend tests"
echo "│   └── requirements.txt            # Python dependencies"
echo "│"
echo "├── 📁 dashboard/                   # Streamlit Dashboard"
echo "│   ├── pages/                      # Multi-page app"
echo "│   ├── components/                 # Reusable components"
echo "│   ├── utils/                      # Utilities"
echo "│   ├── assets/                     # Static assets"
echo "│   └── requirements.txt            # Dashboard dependencies"
echo "│"
echo "├── 📁 hardware/                    # Hardware Design"
echo "├── 📁 docs/                        # Documentation"
echo "├── 📁 tests/                       # System Tests"
echo "├── 📁 data/                        # Data Storage"
echo "├── 📁 scripts/                     # Utility Scripts"
echo "├── 📁 config/                      # Configuration"
echo "├── 📁 logs/                        # System Logs"
echo "├── 📁 deployments/                 # Deployment Configs"
echo "├── README.md                       # Project overview"
echo "├── PROJECT_PLAN.md                 # Timeline & milestones"
echo "├── .env.example                    # Environment template"
echo "└── LICENSE                         # MIT License"
echo ""
echo "🚀 Quick Start Commands:"
echo ""
echo "1. Setup the project:"
echo "   chmod +x scripts/deployment/deploy.sh"
echo "   ./scripts/deployment/deploy.sh"
echo ""
echo "2. Run services manually:"
echo "   # Backend:"
echo "   cd backend && python -m app.main"
echo ""
echo "   # Dashboard:"
echo "   cd dashboard && streamlit run streamlit_app.py"
echo ""
echo "3. Upload firmware:"
echo "   cd firmware"
echo "   # Update WiFi in include/config.h"
echo "   pio run --target upload"
echo "   pio run --target uploadfs"
echo ""
echo "📞 Access Points:"
echo "   • ESP32 Dashboard: http://[ESP32_IP]/"
echo "   • Backend API: http://localhost:8000"
echo "   • API Docs: http://localhost:8000/api/docs"
echo "   • Streamlit Dashboard: http://localhost:8501"
echo ""
echo "🎯 Next Steps:"
echo "   1. Update WiFi credentials in firmware/include/config.h"
echo "   2. Upload firmware to ESP32"
echo "   3. Configure system in config/system/system_config.yaml"
echo "   4. Run deployment script"
echo "   5. Start development!"
echo ""
echo "================================================"
EOF

# Make the script executable
chmod +x create_complete_project.sh

echo ""
echo "📋 To create the complete project structure, run:"
echo "./create_complete_project.sh"
echo ""
echo "This will create ALL folders and files for your complete project!"