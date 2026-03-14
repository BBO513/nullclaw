// Test script to simulate WhatsApp webhook flow

async function testWhatsAppFlow() {
  console.log('🧪 Testing WhatsApp Integration Flow\n');

  const WEBHOOK_URL = 'http://localhost:4180/api/whatsapp';
  const MESSAGES_API = 'http://localhost:4180/api/messages';

  // Simulate Twilio webhook POST
  console.log('1. Simulating WhatsApp message from Twilio...');
  const formData = new URLSearchParams();
  formData.append('From', 'whatsapp:+1234567890');
  formData.append('Body', 'Hello from WhatsApp!');

  try {
    const webhookResponse = await fetch(WEBHOOK_URL, {
      method: 'POST',
      body: formData,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    console.log(`   Status: ${webhookResponse.status}`);
    const twiml = await webhookResponse.text();
    console.log(`   Response: ${twiml.substring(0, 100)}...\n`);

    // Wait a moment for database write
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check database
    console.log('2. Checking database for stored messages...');
    const messagesResponse = await fetch(`${MESSAGES_API}?channel=whatsapp`);
    const messages = await messagesResponse.json();
    
    console.log(`   Found ${messages.length} WhatsApp messages:`);
    messages.forEach((msg, i) => {
      console.log(`   ${i + 1}. [${msg.role}] ${msg.content.substring(0, 50)}...`);
    });

    console.log('\n✅ Test complete! Open http://localhost:4180/chat to see messages in UI');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

testWhatsAppFlow();
