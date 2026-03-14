// WSL tunnel - forwards Windows localhost:3333 to WSL localhost:3333
const net = require('net');
const { spawn } = require('child_process');

const PORT = 3333;

const server = net.createServer((clientSocket) => {
  // Execute curl through WSL to reach the gateway
  const wsl = spawn('wsl', ['bash', '-c', `nc localhost ${PORT}`]);
  
  clientSocket.pipe(wsl.stdin);
  wsl.stdout.pipe(clientSocket);
  
  clientSocket.on('error', () => wsl.kill());
  wsl.on('exit', () => clientSocket.end());
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`\n🔗 WSL Tunnel Active`);
  console.log(`\n  Windows: http://127.0.0.1:${PORT}`);
  console.log(`  WSL:     http://127.0.0.1:${PORT}`);
  console.log(`\n  Press Ctrl+C to stop\n`);
});
