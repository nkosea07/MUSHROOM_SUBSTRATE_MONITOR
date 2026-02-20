#!/bin/bash

# Mushroom Substrate Monitor - Complete Project Setup
# Run this script to set up the entire project structure

echo "🍄 Setting up Mushroom Substrate Monitor Project..."

# Create directory structure
echo "Creating directory structure..."
mkdir -p firmware/{src,include,data,test}
mkdir -p backend/app/{api,core,crud,models,services,utils}
mkdir -p backend/{tests,alembic/versions}
mkdir -p dashboard/{pages,components,utils,assets/{css,images/diagrams,fonts},tests,config}
mkdir -p hardware/{schematics,3d_models,datasheets,calibration}
mkdir -p docs/{project,technical,user,academic,presentations}
mkdir -p tests/{integration,functional,stress,reports}
mkdir -p data/{raw,processed,reports/{daily_reports,weekly_reports,custom_reports},models,backups}
mkdir -p scripts/{deployment,data_processing,monitoring,calibration,maintenance}
mkdir -p config/{system,dashboard,alerts,reports}
mkdir -p logs/{application,sensors,actuators,system}
mkdir -p deployments/{docker,kubernetes,cloud/{aws,azure,gcp},local}
mkdir -p {resources,vendor}

echo "Directory structure created!"

# Create key files
echo "Creating key files..."

# Create README files
cat > README.md << 'EOF'
# 🍄 IoT-Based Automated System for Monitoring and Controlling Mushroom Substrate Conditions
[Content from above]
EOF

cat > firmware/README.md << 'EOF'
# Firmware Setup
[Firmware instructions]
EOF

cat > backend/README.md << 'EOF'
# Backend Setup
[Backend instructions]
EOF

cat > dashboard/README.md << 'EOF'
# Dashboard Setup
[Dashboard instructions]
EOF

# Create requirements files
cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
alembic==1.12.1
pydantic==2.5.0
requests==2.31.0
pandas==2.1.4
numpy==1.24.3
plotly==5.17.0
python-dotenv==1.0.0
psycopg2-binary==2.9.9
redis==5.0.1
celery==5.3.4
python-multipart==0.0.6
email-validator==2.1.0
EOF

cat > dashboard/requirements.txt << 'EOF'
streamlit==1.28.0
plotly==5.17.0
pandas==2.1.4
numpy==1.24.3
requests==2.31.0
pillow==10.1.0
reportlab==4.0.4
python-dotenv==1.0.0
streamlit-option-menu==0.3.6
streamlit-extras==0.3.0
streamlit-aggrid==0.3.4
streamlit-autorefresh==0.1.7
EOF

# Create gitignore
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
EOF

echo "Project structure created successfully!"
echo ""
echo "Next steps:"
echo "1. Review the created structure"
echo "2. Add your ESP32 code to firmware/src/"
echo "3. Configure your backend in backend/app/"
echo "4. Customize the dashboard in dashboard/"
echo "5. Update configuration files in config/"
echo ""
echo "Run 'python -m venv venv' to create virtual environment"
echo "Run 'pip install -r requirements.txt' in each directory"
echo "Run 'streamlit run dashboard/streamlit_app.py' to start dashboard"