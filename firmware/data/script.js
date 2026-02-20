class MushroomDashboard {
    constructor() {
        this.apiBase = '/api';
        this.refreshInterval = 5000; // 5 seconds
        this.refreshTimer = null;
        this.startTime = Date.now();
        
        this.init();
    }
    
    init() {
        console.log('Initializing Mushroom Dashboard...');
        
        // Load initial data
        this.fetchData();
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Start auto-refresh
        this.startAutoRefresh();
        
        // Update uptime every second
        setInterval(() => this.updateUptime(), 1000);
    }
    
    async fetchData() {
        try {
            const response = await fetch(`${this.apiBase}/data`);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            const data = await response.json();
            this.updateDashboard(data);
            this.updateLastUpdateTime();
            
        } catch (error) {
            console.error('Error fetching data:', error);
            this.addAlert(`Connection error: ${error.message}`, 'critical');
            document.getElementById('wifi-status').className = 'status-critical';
            document.getElementById('wifi-status').textContent = 'Disconnected';
        }
    }
    
    updateDashboard(data) {
        // Update temperature
        const temp = data.temperature || 0;
        const tempMin = data.thresholds?.temp_min || 22;
        const tempMax = data.thresholds?.temp_max || 26;
        
        document.getElementById('temp-value').textContent = `${temp.toFixed(1)}°C`;
        this.updateStatus('temp', temp, tempMin, tempMax);
        document.getElementById('temp-range').textContent = `${tempMin}-${tempMax}°C`;
        
        // Update moisture
        const moisture = data.moisture || 0;
        const moistureMin = data.thresholds?.moisture_min || 60;
        const moistureMax = data.thresholds?.moisture_max || 70;
        
        document.getElementById('moisture-value').textContent = `${moisture}%`;
        this.updateStatus('moisture', moisture, moistureMin, moistureMax);
        document.getElementById('moisture-range').textContent = `${moistureMin}-${moistureMax}%`;
        
        // Update pH
        const ph = data.ph || 7.0;
        const phMin = data.thresholds?.ph_min || 6.5;
        const phMax = data.thresholds?.ph_max || 7.0;
        
        document.getElementById('ph-value').textContent = ph.toFixed(2);
        this.updateStatus('ph', ph, phMin, phMax);
        document.getElementById('ph-range').textContent = `${phMin}-${phMax}`;
        
        // Update system status
        document.getElementById('system-fan').textContent = data.status?.fan || 'OFF';
        document.getElementById('system-fan').className = 
            data.status?.fan === 'ON' ? 'status-on' : 'status-off';
            
        document.getElementById('system-heater').textContent = data.status?.heater || 'OFF';
        document.getElementById('system-heater').className = 
            data.status?.heater === 'ON' ? 'status-on' : 'status-off';
            
        document.getElementById('system-humidifier').textContent = data.status?.humidifier || 'OFF';
        document.getElementById('system-humidifier').className = 
            data.status?.humidifier === 'ON' ? 'status-on' : 'status-off';
            
        document.getElementById('system-mode').textContent = data.status?.mode || 'AUTO';
        document.getElementById('system-mode').className = 'status-auto';
        
        // Update WiFi info
        if (data.wifi) {
            document.getElementById('wifi-rssi').textContent = data.wifi.rssi || '-';
            document.getElementById('esp-ip').textContent = data.wifi.ip || 'Unknown';
        }
    }
    
    updateStatus(type, value, min, max) {
        const element = document.getElementById(`${type}-status`);
        
        if (value < min) {
            element.textContent = 'TOO LOW';
            element.className = 'status-critical';
            this.addAlert(`${type.charAt(0).toUpperCase() + type.slice(1)} too low: ${value}`, 'critical');
        } else if (value > max) {
            element.textContent = 'TOO HIGH';
            element.className = 'status-critical';
            this.addAlert(`${type.charAt(0).toUpperCase() + type.slice(1)} too high: ${value}`, 'critical');
        } else if (value >= min && value <= max) {
            element.textContent = 'OPTIMAL';
            element.className = 'status-optimal';
        } else {
            element.textContent = 'UNKNOWN';
            element.className = '';
        }
    }
    
    async sendControl(command) {
        try {
            const response = await fetch(`${this.apiBase}/control`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(command)
            });
            
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            this.addAlert(`Control command sent: ${JSON.stringify(command)}`, 'info');
            this.fetchData(); // Refresh data
            
        } catch (error) {
            console.error('Error sending control:', error);
            this.addAlert(`Control failed: ${error.message}`, 'critical');
        }
    }
    
    addAlert(message, type = 'info') {
        const alertsList = document.getElementById('alerts-list');
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert ${type}`;
        
        const time = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        alertDiv.textContent = `[${time}] ${message}`;
        
        alertsList.insertBefore(alertDiv, alertsList.firstChild);
        
        // Limit to 10 alerts
        while (alertsList.children.length > 10) {
            alertsList.removeChild(alertsList.lastChild);
        }
        
        // Auto-remove after 30 seconds for non-critical alerts
        if (type !== 'critical') {
            setTimeout(() => {
                if (alertDiv.parentNode) {
                    alertDiv.style.opacity = '0.5';
                    setTimeout(() => {
                        if (alertDiv.parentNode) {
                            alertsList.removeChild(alertDiv);
                        }
                    }, 1000);
                }
            }, 30000);
        }
    }
    
    updateLastUpdateTime() {
        const now = new Date();
        const timeString = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
        document.getElementById('last-update').textContent = `Last Update: ${timeString}`;
    }
    
    updateUptime() {
        const elapsed = Date.now() - this.startTime;
        const hours = Math.floor(elapsed / 3600000);
        const minutes = Math.floor((elapsed % 3600000) / 60000);
        const seconds = Math.floor((elapsed % 60000) / 1000);
        
        document.getElementById('uptime').textContent = 
            `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
    
    startAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }
        
        this.refreshTimer = setInterval(() => {
            this.fetchData();
        }, this.refreshInterval);
    }
    
    setupEventListeners() {
        // Mode selector
        document.getElementById('mode-auto').addEventListener('click', () => {
            document.getElementById('mode-auto').classList.add('active');
            document.getElementById('mode-manual').classList.remove('active');
            document.getElementById('manual-controls').style.display = 'none';
            this.sendControl({ mode: 'AUTO' });
        });
        
        document.getElementById('mode-manual').addEventListener('click', () => {
            document.getElementById('mode-manual').classList.add('active');
            document.getElementById('mode-auto').classList.remove('active');
            document.getElementById('manual-controls').style.display = 'block';
            this.sendControl({ mode: 'MANUAL' });
        });
        
        // Actuator buttons
        document.getElementById('fan-btn').addEventListener('click', (e) => {
            const isOn = e.target.classList.contains('on');
            const newState = !isOn;
            e.target.textContent = newState ? 'ON' : 'OFF';
            e.target.className = `actuator-btn ${newState ? 'on' : 'off'}`;
            this.sendControl({ fan: newState ? 'ON' : 'OFF' });
        });
        
        document.getElementById('heater-btn').addEventListener('click', (e) => {
            const isOn = e.target.classList.contains('on');
            const newState = !isOn;
            e.target.textContent = newState ? 'ON' : 'OFF';
            e.target.className = `actuator-btn ${newState ? 'on' : 'off'}`;
            this.sendControl({ heater: newState ? 'ON' : 'OFF' });
        });
        
        document.getElementById('humidifier-btn').addEventListener('click', (e) => {
            const isOn = e.target.classList.contains('on');
            const newState = !isOn;
            e.target.textContent = newState ? 'ON' : 'OFF';
            e.target.className = `actuator-btn ${newState ? 'on' : 'off'}`;
            this.sendControl({ humidifier: newState ? 'ON' : 'OFF' });
        });
        
        // Refresh button
        document.getElementById('refresh-btn').addEventListener('click', () => {
            this.fetchData();
        });
    }
}

// Initialize dashboard when page loads
document.addEventListener('DOMContentLoaded', () => {
    new MushroomDashboard();
});
