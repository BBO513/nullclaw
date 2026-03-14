// Auto-pairing script for NullClaw gateway
// This script automatically detects and pairs with the gateway

const fetch = require('node-fetch');

class AutoPair {
  constructor(gatewayUrl = 'http://127.0.0.1:3001') {
    this.gatewayUrl = gatewayUrl;
    this.paired = false;
    this.token = null;
  }

  async getPairingCodeFromTerminal() {
    // This is a placeholder - in a real implementation, you would:
    // 1. Monitor the gateway terminal output
    // 2. Parse the pairing code from the logs
    // 3. Return the code
    
    console.log('Monitoring gateway for pairing code...');
    
    // For now, we'll simulate by checking the gateway health
    // and returning a mock code that would need to be entered manually
    try {
      const response = await fetch(`${this.gatewayUrl}/health`);
      if (response.ok) {
        console.log('Gateway is running. Please check terminal for pairing code.');
        return null; // Need manual entry
      }
    } catch (error) {
      console.log('Gateway not responding.');
    }
    
    return null;
  }

  async pairWithCode(code) {
    try {
      const response = await fetch(`${this.gatewayUrl}/pair`, {
        method: 'POST',
        headers: {
          'X-Pairing-Code': code
        }
      });

      if (response.ok) {
        const data = await response.json();
        this.token = data.token;
        this.paired = true;
        console.log('✅ Successfully paired with gateway!');
        console.log(`Token: ${this.token.substring(0, 20)}...`);
        return true;
      } else {
        console.log('❌ Invalid pairing code');
        return false;
      }
    } catch (error) {
      console.log('❌ Failed to connect to gateway:', error.message);
      return false;
    }
  }

  async autoPair() {
    console.log('Starting auto-pairing system...');
    
    // Step 1: Check if gateway is running
    console.log('Checking gateway health...');
    try {
      const healthResponse = await fetch(`${this.gatewayUrl}/health`);
      if (!healthResponse.ok) {
        console.log('❌ Gateway is not responding. Please start the gateway first.');
        return false;
      }
      console.log('✅ Gateway is running');
    } catch (error) {
      console.log('❌ Cannot connect to gateway:', error.message);
      return false;
    }

    // Step 2: Try to get pairing code (this would need terminal monitoring)
    console.log('Note: Auto-pairing requires terminal monitoring.');
    console.log('For now, please enter the pairing code manually from the gateway terminal.');
    
    return false;
  }

  async sendTestMessage() {
    if (!this.paired || !this.token) {
      console.log('Not paired with gateway');
      return false;
    }

    try {
      const response = await fetch(`${this.gatewayUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: 'llama3.1',
          messages: [
            { role: 'user', content: 'Test message from auto-pair system' }
          ]
        })
      });

      if (response.ok) {
        const data = await response.json();
        const reply = data.choices?.[0]?.message?.content || 'No reply';
        console.log('✅ Test message sent successfully:', reply);
        return true;
      } else {
        console.log('❌ Failed to send test message:', response.statusText);
        return false;
      }
    } catch (error) {
      console.log('❌ Error sending test message:', error.message);
      return false;
    }
  }
}

// Export for use in other scripts
module.exports = AutoPair;

// If run directly
if (require.main === module) {
  const autoPair = new AutoPair();
  
  // Check for command line arguments
  const args = process.argv.slice(2);
  
  if (args.length > 0 && args[0] === '--pair') {
    if (args.length > 1) {
      // Pair with provided code
      autoPair.pairWithCode(args[1]);
    } else {
      // Try auto-pair
      autoPair.autoPair();
    }
  } else {
    console.log('Usage:');
    console.log('  node auto-pair.js --pair [code]  - Pair with specific code');
    console.log('  node auto-pair.js --pair         - Try auto-pairing');
  }
}