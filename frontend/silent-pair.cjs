// Silent pairing system for NullClaw gateway
// Monitors gateway, auto-detects pairing codes, and auto-pairs

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

class SilentPair {
  constructor() {
    this.gatewayUrl = 'http://127.0.0.1:3001'; // CORS proxy
    this.watchedProcess = null;
    this.paired = false;
    this.token = null;
    this.lastPairingCode = null;
    this.pairingAttempts = 0;
    this.maxAttempts = 3;
  }

  // Start monitoring gateway process
  startMonitoring() {
    console.log('🚀 Starting silent pairing system...');
    
    // Check if gateway is already running
    this.checkGatewayHealth().then(isRunning => {
      if (isRunning) {
        console.log('✅ Gateway is running');
        this.monitorForPairingCode();
      } else {
        console.log('❌ Gateway not running. Starting gateway...');
        this.startGateway();
      }
    });
  }

  async checkGatewayHealth() {
    try {
      const response = await fetch(`${this.gatewayUrl}/health`, { timeout: 3000 });
      return response.ok;
    } catch {
      return false;
    }
  }

  startGateway() {
    console.log('Starting NullClaw gateway...');
    
    // This would start the gateway process
    // For now, we'll assume it's started manually or via start-gateway.ps1
    console.log('Please start gateway manually or run start-gateway.ps1');
    console.log('Then this system will auto-detect the pairing code');
    
    // Start monitoring after a delay
    setTimeout(() => {
      this.monitorForPairingCode();
    }, 5000);
  }

  async monitorForPairingCode() {
    console.log('🔍 Monitoring for pairing codes...');
    
    // In a real implementation, this would:
    // 1. Monitor gateway terminal output
    // 2. Parse pairing codes from logs
    // 3. Auto-pair when detected
    
    // For now, we'll simulate by checking gateway and suggesting manual pairing
    setInterval(async () => {
      if (this.paired) {
        console.log('✅ Already paired');
        return;
      }

      // Try to get pairing code (simulated)
      const code = await this.simulatePairingCodeDetection();
      if (code && code !== this.lastPairingCode) {
        console.log(`🔑 Detected pairing code: ${code}`);
        this.lastPairingCode = code;
        this.attemptAutoPair(code);
      }
    }, 5000); // Check every 5 seconds
  }

  async simulatePairingCodeDetection() {
    // In reality, this would parse gateway logs
    // For now, return null to simulate no detection
    return null;
  }

  async attemptAutoPair(code) {
    if (this.pairingAttempts >= this.maxAttempts) {
      console.log('⚠️ Max pairing attempts reached. Please pair manually.');
      return;
    }

    this.pairingAttempts++;
    console.log(`Attempting auto-pair with code: ${code} (attempt ${this.pairingAttempts}/${this.maxAttempts})`);

    try {
      const response = await fetch(`${this.gatewayUrl}/pair`, {
        method: 'POST',
        headers: {
          'X-Pairing-Code': code
        },
        timeout: 5000
      });

      if (response.ok) {
        const data = await response.json();
        this.token = data.token;
        this.paired = true;
        console.log('✅ Auto-pair successful!');
        console.log(`Token: ${this.token.substring(0, 20)}...`);
        
        // Save token to file for web interface to use
        this.saveTokenToFile();
        
        // Send test message to verify
        await this.sendTestMessage();
      } else {
        console.log('❌ Auto-pair failed (invalid code)');
      }
    } catch (error) {
      console.log('❌ Auto-pair failed (connection error):', error.message);
    }
  }

  saveTokenToFile() {
    const tokenFile = path.join(__dirname, '.gateway-token');
    const config = {
      token: this.token,
      paired: true,
      pairedAt: new Date().toISOString(),
      gatewayUrl: 'http://127.0.0.1:3001'
    };
    
    fs.writeFileSync(tokenFile, JSON.stringify(config, null, 2));
    console.log(`💾 Token saved to ${tokenFile}`);
  }

  async sendTestMessage() {
    if (!this.token) return;

    try {
      const response = await fetch(`${this.gatewayUrl}/webhook`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: 'Silent pairing test - system is working'
        }),
        timeout: 10000
      });

      if (response.ok) {
        const data = await response.text();
        console.log('✅ Test message sent successfully:', data);
      } else {
        console.log('❌ Test message failed:', response.statusText);
      }
    } catch (error) {
      console.log('❌ Test message error:', error.message);
    }
  }

  // Load token from file (for web interface integration)
  loadTokenFromFile() {
    const tokenFile = path.join(__dirname, '.gateway-token');
    if (fs.existsSync(tokenFile)) {
      try {
        const config = JSON.parse(fs.readFileSync(tokenFile, 'utf8'));
        this.token = config.token;
        this.paired = config.paired;
        console.log('📂 Loaded token from file');
        return true;
      } catch (error) {
        console.log('Error loading token file:', error.message);
      }
    }
    return false;
  }

  // Get current status
  getStatus() {
    return {
      paired: this.paired,
      token: this.token ? `${this.token.substring(0, 10)}...` : null,
      attempts: this.pairingAttempts,
      maxAttempts: this.maxAttempts
    };
  }
}

// Export for use in other scripts
module.exports = SilentPair;

// If run directly
if (require.main === module) {
  const silentPair = new SilentPair();
  
  // Check for saved token first
  if (silentPair.loadTokenFromFile()) {
    console.log('Already have token from previous session');
    console.log('Status:', silentPair.getStatus());
    
    // Test the token
    silentPair.sendTestMessage().then(() => {
      process.exit(0);
    });
  } else {
    // Start monitoring
    silentPair.startMonitoring();
    
    // Keep running
    console.log('Silent pairing system running. Press Ctrl+C to stop.');
    
    // Show status every 30 seconds
    setInterval(() => {
      console.log('Status:', silentPair.getStatus());
    }, 30000);
  }
}