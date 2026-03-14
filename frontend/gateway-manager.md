# NullClaw Gateway Manager

## Overview
This system manages the NullClaw gateway lifecycle, including automatic restarts, pairing, and monitoring.

## Files Created

### 1. `start-gateway.ps1`
- PowerShell script to start and monitor the gateway
- Auto-restarts the gateway if it crashes
- Handles graceful shutdown on script termination

### 2. `start-system.bat`
- Batch file to start the entire system:
  - CORS Proxy (port 3001)
  - Gateway Manager (WSL gateway)
  - Web interface instructions

### 3. `auto-pair.js`
- Node.js script for automatic pairing
- Can monitor gateway output for pairing codes
- Provides test messaging functionality

## Usage

### Quick Start
1. Run `start-system.bat` to launch everything
2. Access the web interface at `http://localhost:4174/`
3. Pair with the gateway using the code from the terminal

### Manual Gateway Management
```powershell
# Start gateway with auto-restart
.\start-gateway.ps1

# Start CORS proxy
node cors-proxy.cjs

# Start web interface
npm run preview -- --port 4174
```

### Auto-Pairing (Future Enhancement)
```bash
# Pair with specific code
node auto-pair.js --pair 123456

# Try auto-pairing (requires terminal monitoring)
node auto-pair.js --pair
```

## Current Pairing Flow
1. Gateway starts and displays a 6-digit pairing code
2. User enters code in the web interface
3. Web interface stores bearer token in localStorage
4. All subsequent requests use the bearer token

## Future Improvements
- [ ] Terminal output monitoring to auto-detect pairing codes
- [ ] Automatic token refresh before expiration
- [ ] Health monitoring dashboard
- [ ] Configuration file for gateway settings
- [ ] Multiple gateway instance support

## Notes
- Pairing codes expire quickly (security feature)
- Gateway runs in WSL Ubuntu at `127.0.0.1:3000`
- CORS proxy runs at `127.0.0.1:3001` for browser access
- Bearer tokens are stored encrypted by the gateway