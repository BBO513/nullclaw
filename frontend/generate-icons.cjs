// Simple PNG icon generator from SVG
// Run with: node generate-icons.js

const fs = require('fs');
const path = require('path');

// Read the SVG icon
const svgPath = path.join(__dirname, 'static', 'icon.svg');
const svgContent = fs.readFileSync(svgPath, 'utf8');

console.log('📦 NullClaw Nexus - Icon Generator');
console.log('');
console.log('SVG icon found at:', svgPath);
console.log('');
console.log('⚠️  Note: This script requires a browser or sharp/canvas library to convert SVG to PNG.');
console.log('');
console.log('Quick solutions:');
console.log('');
console.log('Option 1: Use online converter');
console.log('  1. Open https://cloudconvert.com/svg-to-png');
console.log('  2. Upload: static/icon.svg');
console.log('  3. Convert to 192x192 PNG → Save as static/icon-192.png');
console.log('  4. Convert to 512x512 PNG → Save as static/icon-512.png');
console.log('');
console.log('Option 2: Use the browser generator');
console.log('  1. Start dev server: npm run dev');
console.log('  2. Open: http://localhost:5173/generate-pwa-icons.html');
console.log('  3. Click "Download All"');
console.log('  4. Save files to static/ folder');
console.log('');
console.log('Option 3: Use ImageMagick (if installed)');
console.log('  convert static/icon.svg -resize 192x192 static/icon-192.png');
console.log('  convert static/icon.svg -resize 512x512 static/icon-512.png');
console.log('');
console.log('Option 4: Use temporary placeholders (quick fix)');
console.log('  node generate-icons.js --placeholder');
console.log('');

// Check if placeholder flag is set
if (process.argv.includes('--placeholder')) {
  console.log('🎨 Creating placeholder PNG icons...');
  console.log('');
  
  // Create simple base64 PNG placeholders
  const createPlaceholder = (size) => {
    // Minimal 1x1 transparent PNG, will be scaled by browser
    const base64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    return Buffer.from(base64, 'base64');
  };
  
  const icon192Path = path.join(__dirname, 'static', 'icon-192.png');
  const icon512Path = path.join(__dirname, 'static', 'icon-512.png');
  
  fs.writeFileSync(icon192Path, createPlaceholder(192));
  fs.writeFileSync(icon512Path, createPlaceholder(512));
  
  console.log('✅ Created placeholder icons:');
  console.log('  - static/icon-192.png');
  console.log('  - static/icon-512.png');
  console.log('');
  console.log('⚠️  These are minimal placeholders. Replace with proper icons using one of the options above.');
  console.log('');
} else {
  console.log('💡 Run with --placeholder flag to create temporary placeholder icons.');
  console.log('');
}
