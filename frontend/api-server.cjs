// Simple API server for NullClaw agent/swarm/memory management
// Runs on port 3334, shares token with gateway

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3334;
// Token file is in WSL - access via \\wsl.localhost\Ubuntu-22.04\home\agentzero\nullclaw-wsl\nullclaw.token
const TOKEN_FILE = '\\\\wsl.localhost\\Ubuntu-22.04\\home\\agentzero\\nullclaw-wsl\\nullclaw.token';
const MASTER_KEY = 'NULLCLAW-CREATOR-UNLIMITED';

// In-memory stores
const agents = [];
const swarms = [];
const memory = [];
let nextId = 1;

// Read token from file
function getStoredToken() {
  try {
    return fs.readFileSync(TOKEN_FILE, 'utf8').trim();
  } catch (err) {
    return null;
  }
}

// Authenticate request
function authenticate(req) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return false;
  }
  
  const token = auth.substring(7);
  
  // Check master key
  if (token === MASTER_KEY) {
    return true;
  }
  
  // Check stored token
  const storedToken = getStoredToken();
  if (storedToken && token === storedToken) {
    return true;
  }
  
  return false;
}

// Parse JSON body
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        resolve(JSON.parse(body));
      } catch (err) {
        reject(err);
      }
    });
  });
}

// Send JSON response
function sendJSON(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify(data));
}

// Handle requests
const server = http.createServer(async (req, res) => {
  console.log(`${req.method} ${req.url}`);
  
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
    res.end();
    return;
  }
  
  // Authenticate
  if (!authenticate(req)) {
    sendJSON(res, 401, { error: 'unauthorized' });
    return;
  }
  
  // Route handling
  if (req.method === 'GET' && req.url === '/api/agents') {
    sendJSON(res, 200, agents);
  }
  else if (req.method === 'POST' && req.url === '/api/agents') {
    try {
      const body = await parseBody(req);
      const agent = {
        id: `agent_${nextId++}`,
        name: body.name,
        model: body.model,
        status: 'active',
        created_at: Math.floor(Date.now() / 1000),
      };
      agents.push(agent);
      sendJSON(res, 201, agent);
    } catch (err) {
      sendJSON(res, 400, { error: 'invalid request' });
    }
  }
  else if (req.method === 'GET' && req.url === '/api/swarms') {
    sendJSON(res, 200, swarms);
  }
  else if (req.method === 'POST' && req.url === '/api/swarms') {
    try {
      const body = await parseBody(req);
      const swarm = {
        id: `swarm_${nextId++}`,
        name: body.name,
        agents: [],
      };
      swarms.push(swarm);
      sendJSON(res, 201, swarm);
    } catch (err) {
      sendJSON(res, 400, { error: 'invalid request' });
    }
  }
  else if (req.method === 'GET' && req.url === '/api/memory') {
    sendJSON(res, 200, memory);
  }
  else if (req.method === 'POST' && req.url === '/api/memory') {
    try {
      const body = await parseBody(req);
      const file = {
        id: `memory_${nextId++}`,
        name: body.name,
        size: (body.content || '').length,
        uploaded_at: Math.floor(Date.now() / 1000),
        path: `./memory/${body.name}`,
      };
      memory.push(file);
      sendJSON(res, 201, file);
    } catch (err) {
      sendJSON(res, 400, { error: 'invalid request' });
    }
  }
  else {
    sendJSON(res, 404, { error: 'not found' });
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('🚀 NullClaw API Server');
  console.log('');
  console.log(`  Listening: http://127.0.0.1:${PORT}`);
  console.log(`  Token file: ${TOKEN_FILE}`);
  console.log('');
  console.log('  Endpoints:');
  console.log('    GET  /api/agents');
  console.log('    POST /api/agents');
  console.log('    GET  /api/swarms');
  console.log('    POST /api/swarms');
  console.log('    GET  /api/memory');
  console.log('    POST /api/memory');
  console.log('');
  console.log('  Press Ctrl+C to stop');
  console.log('');
});
