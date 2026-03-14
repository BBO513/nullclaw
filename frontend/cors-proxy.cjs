// Simple CORS proxy for NullClaw gateway
// This adds CORS headers to allow browser requests from the dev server

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const GATEWAY_HOST = '127.0.0.1'; // WSL auto-forwards to Windows localhost
const GATEWAY_PORT = 3333;
const PROXY_PORT = 3001;

// Master keys for zero-config pairing
const MASTER_KEYS = [
  'NULLCLAW-CREATOR-UNLIMITED',
  'NULLCLAW-MASTER-KEY',
  'NULLCLAW-ADMIN-ACCESS'
];

// Token file path (same as gateway uses)
const TOKEN_FILE = path.join(__dirname, 'nullclaw.token');

const server = http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`);

  // Handle preflight OPTIONS requests
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Pairing-Code, X-Master-Key',
      'Access-Control-Max-Age': '86400',
    });
    res.end();
    return;
  }

  // Handle master key pairing endpoint
  if (req.method === 'POST' && req.url === '/pair-with-master') {
    const masterKey = req.headers['x-master-key'];
    
    if (!masterKey || !MASTER_KEYS.includes(masterKey)) {
      res.writeHead(401, {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json',
      });
      res.end(JSON.stringify({ error: 'Invalid master key' }));
      return;
    }

    // Generate a bearer token
    const token = crypto.randomBytes(32).toString('hex');
    
    // Save token to file (same as gateway does)
    try {
      fs.writeFileSync(TOKEN_FILE, token, 'utf8');
      console.log(`✅ Master key pairing successful - Token saved to ${TOKEN_FILE}`);
    } catch (err) {
      console.error('Failed to save token:', err.message);
    }

    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
    });
    res.end(JSON.stringify({ 
      status: 'paired',
      token: token,
      message: 'Successfully paired with master key'
    }));
    return;
  }

  // Proxy the request to the gateway
  const options = {
    hostname: GATEWAY_HOST,
    port: GATEWAY_PORT,
    path: req.url,
    method: req.method,
    headers: req.headers,
  };

  const proxyReq = http.request(options, (proxyRes) => {
    // Add CORS headers to the response
    const headers = {
      ...proxyRes.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Pairing-Code',
    };

    res.writeHead(proxyRes.statusCode, headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy error:', err.message);
    res.writeHead(502, {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
    });
    res.end(JSON.stringify({ error: 'Gateway unavailable', details: err.message }));
  });

  // Forward the request body
  req.pipe(proxyReq);
});

server.listen(PROXY_PORT, '127.0.0.1', () => {
  console.log('');
  console.log('🔄 CORS Proxy for NullClaw Gateway');
  console.log('');
  console.log(`  Proxy:   http://127.0.0.1:${PROXY_PORT}`);
  console.log(`  Gateway: http://${GATEWAY_HOST}:${GATEWAY_PORT}`);
  console.log('');
  console.log('  Endpoints:');
  console.log('    POST /pair-with-master  - Zero-config pairing with master key');
  console.log('    POST /pair              - Standard pairing with code');
  console.log('    All other requests      - Proxied to gateway');
  console.log('');
  console.log('  Master Keys:');
  MASTER_KEYS.forEach(key => console.log(`    - ${key}`));
  console.log('');
  console.log('  Press Ctrl+C to stop');
  console.log('');
});
