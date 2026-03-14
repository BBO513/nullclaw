# NullClaw Gateway Pairing System

## Overview

The NullClaw Gateway uses a secure pairing system to authenticate web clients without requiring traditional username/password credentials. This document explains how the pairing system works, its security model, and how to use it.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Web Browser   │◄───────►│   CORS Proxy     │◄───────►│ NullClaw Gateway│
│  (localhost)    │         │  (port 3001)     │         │   (port 3000)   │
└─────────────────┘         └──────────────────┘         └─────────────────┘
        │                                                          │
        │ 1. Request pairing code                                 │
        │ 2. Enter 6-digit code ──────────────────────────────────►
        │                                                          │
        │ 3. Receive bearer token ◄───────────────────────────────┤
        │                                                          │
        │ 4. Store token in localStorage                          │
        │                                                          │
        │ 5. Use token for all API calls ─────────────────────────►
        └──────────────────────────────────────────────────────────┘
```

## How It Works

### 1. Gateway Generates Pairing Code

When the NullClaw gateway starts, it automatically generates a 6-digit pairing code:

```bash
$ ./nullclaw gateway --bind 127.0.0.1:3000

NullClaw Gateway v2026.3.4
Listening on 127.0.0.1:3000
Pairing code: 267074
Code expires in: 5 minutes
```

**Security Features:**
- Code is randomly generated (6 digits: 000000-999999)
- Code expires after 5 minutes for security
- New code generated on each gateway restart
- Code displayed only in terminal (not in logs)

### 2. User Initiates Pairing

From the web interface:

1. Navigate to **Settings** page
2. Click **"Pair Now"** button
3. Pairing modal appears

### 3. Code Exchange

The user enters the 6-digit code from the gateway terminal:

```
┌─────────────────────────────────────┐
│  Pair with NullClaw Gateway         │
├─────────────────────────────────────┤
│                                     │
│  Enter 6-digit code: [2][6][7][0]  │
│                      [7][4]         │
│                                     │
│  [Cancel]           [Pair Now]      │
└─────────────────────────────────────┘
```

### 4. Token Generation

When the code is submitted:

```typescript
// Client sends pairing request
POST http://127.0.0.1:3001/pair
Headers:
  X-Pairing-Code: 267074

// Gateway validates code and returns token
Response:
{
  "status": "paired",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 5. Token Storage

The bearer token is stored in browser localStorage:

```javascript
localStorage.setItem('gatewayConfig', JSON.stringify({
  url: 'http://127.0.0.1:3001',
  bearerToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  paired: true,
  connected: true
}));
```

### 6. Authenticated Requests

All subsequent API calls include the bearer token:

```typescript
// Example: Send message to gateway
POST http://127.0.0.1:3001/webhook
Headers:
  Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  Content-Type: application/json
Body:
{
  "message": "Hello from web interface"
}
```

## Security Model

### Why Pairing Instead of Login?

1. **No Password Management**: No need to remember/store passwords
2. **Physical Access Required**: Must have terminal access to see code
3. **Time-Limited**: Codes expire quickly (5 minutes)
4. **Single-Use**: Each code can only be used once
5. **Local-First**: Designed for localhost/LAN use

### Security Considerations

**✅ Secure For:**
- Local development (localhost)
- Private networks (LAN)
- Single-user systems
- Trusted environments

**⚠️ Not Recommended For:**
- Public internet exposure
- Multi-tenant systems
- Production deployments without HTTPS
- Untrusted networks

### Best Practices

1. **Use Localhost**: Always use `127.0.0.1` for maximum security
2. **CORS Proxy**: Browser requires CORS proxy at port 3001
3. **Code Expiry**: Don't share codes; they expire in 5 minutes
4. **Token Rotation**: Re-pair periodically for fresh tokens
5. **HTTPS**: Use HTTPS in production environments

## CORS Proxy Setup

The web browser cannot directly access the gateway due to CORS restrictions. A simple proxy is required:

### Start CORS Proxy

```bash
cd nullclaw-nexus
node cors-proxy.cjs
```

The proxy runs on `http://127.0.0.1:3001` and forwards requests to the gateway at `http://127.0.0.1:3000`.

### Proxy Configuration

```javascript
// cors-proxy.cjs
const http = require('http');
const httpProxy = require('http-proxy');

const proxy = httpProxy.createProxyServer({
  target: 'http://127.0.0.1:3000',
  changeOrigin: true
});

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Pairing-Code');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  proxy.web(req, res);
});

server.listen(3001);
```

## Usage Guide

### First-Time Setup

1. **Start Gateway**:
   ```bash
   cd nullclaw
   ./zig-out/bin/nullclaw gateway --bind 127.0.0.1:3000
   ```
   Note the 6-digit pairing code displayed.

2. **Start CORS Proxy**:
   ```bash
   cd nullclaw-nexus
   node cors-proxy.cjs
   ```

3. **Start Web Interface**:
   ```bash
   cd nullclaw-nexus
   npm run preview -- --port 4180
   ```

4. **Pair the Client**:
   - Open `http://localhost:4180/settings`
   - Click "Pair Now"
   - Enter the 6-digit code from step 1
   - Click "Pair Now" in modal

5. **Verify Connection**:
   - Status should show "✅ Paired"
   - Green indicator appears
   - Bearer token stored in localStorage

### Re-Pairing

If the gateway restarts or the token expires:

1. Check terminal for new pairing code
2. Go to Settings → Click "Re-pair"
3. Enter new code
4. Token automatically updates

### Unpairing

To disconnect the client:

1. Go to Settings
2. Click "Unpair" button
3. Confirm the action
4. Token removed from localStorage

## Troubleshooting

### "Invalid pairing code"

**Causes:**
- Code expired (>5 minutes old)
- Code already used
- Gateway restarted (new code generated)
- Typo in code entry

**Solution:**
- Check terminal for current code
- Ensure code is fresh (<5 minutes)
- Try new pairing attempt

### "Connection failed"

**Causes:**
- Gateway not running
- CORS proxy not running
- Wrong port configuration
- Firewall blocking connection

**Solution:**
```bash
# Check gateway is running
curl http://127.0.0.1:3000/health

# Check CORS proxy is running
curl http://127.0.0.1:3001/health

# Verify ports
netstat -an | grep "3000\|3001"
```

### "Unauthorized" errors

**Causes:**
- Token expired
- Token invalid
- Gateway restarted (tokens invalidated)

**Solution:**
- Re-pair with new code
- Check Settings shows "✅ Paired"

## API Reference

### POST /pair

Exchange pairing code for bearer token.

**Request:**
```http
POST /pair HTTP/1.1
Host: 127.0.0.1:3001
X-Pairing-Code: 267074
```

**Response (Success):**
```json
{
  "status": "paired",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (Error):**
```json
{
  "error": "Invalid pairing code"
}
```

### POST /webhook

Send message to gateway (requires authentication).

**Request:**
```http
POST /webhook HTTP/1.1
Host: 127.0.0.1:3001
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "message": "Hello, NullClaw!"
}
```

**Response:**
```json
{
  "status": "received"
}
```

### GET /health

Check gateway health (no authentication required).

**Request:**
```http
GET /health HTTP/1.1
Host: 127.0.0.1:3001
```

**Response:**
```json
{
  "status": "ok",
  "version": "2026.3.4"
}
```

## Integration Examples

### JavaScript/TypeScript

```typescript
import { GatewayAPI } from '$lib/api/gateway';

// Initialize API client
const api = new GatewayAPI('http://127.0.0.1:3001', bearerToken);

// Pair with gateway
const result = await api.pair('267074');
if (result) {
  console.log('Paired! Token:', result.token);
  // Store token for future use
  localStorage.setItem('bearerToken', result.token);
}

// Send message
const response = await api.sendMessage('default', 'Hello!');
console.log('Response:', response);
```

### Python

```python
import requests

# Pair with gateway
response = requests.post(
    'http://127.0.0.1:3001/pair',
    headers={'X-Pairing-Code': '267074'}
)
token = response.json()['token']

# Send message
response = requests.post(
    'http://127.0.0.1:3001/webhook',
    headers={'Authorization': f'Bearer {token}'},
    json={'message': 'Hello from Python!'}
)
print(response.json())
```

### cURL

```bash
# Pair with gateway
TOKEN=$(curl -s -X POST http://127.0.0.1:3001/pair \
  -H "X-Pairing-Code: 267074" | jq -r '.token')

# Send message
curl -X POST http://127.0.0.1:3001/webhook \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from cURL!"}'
```

## Future Enhancements

Planned improvements to the pairing system:

- [ ] QR code pairing (scan code instead of typing)
- [ ] Token refresh mechanism
- [ ] Multiple client support with device names
- [ ] Pairing history and audit log
- [ ] Revoke specific tokens
- [ ] OAuth2-style scopes for permissions
- [ ] WebSocket support for real-time updates

## Related Documentation

- [Gateway API Reference](./nullclaw-nexus/src/lib/api/gateway.ts)
- [Settings Page](./nullclaw-nexus/src/routes/settings/+page.svelte)
- [Pairing Modal Component](./nullclaw-nexus/src/lib/components/PairingModal.svelte)
- [Gateway Store](./nullclaw-nexus/src/lib/stores/gateway.ts)

## Support

For issues or questions about the pairing system:

1. Check gateway terminal for current pairing code
2. Verify CORS proxy is running on port 3001
3. Check browser console for error messages
4. Review this documentation
5. Open issue on GitHub: https://github.com/nullclaw/nullclaw

---

**Last Updated**: March 6, 2026  
**Version**: 1.0.0  
**Status**: Production Ready
