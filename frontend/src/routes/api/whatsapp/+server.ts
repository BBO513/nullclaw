import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { db } from '$lib/db';
import { messages } from '$lib/db/schema';

const GATEWAY_URL = 'http://127.0.0.1:3333';
const BEARER_TOKEN = process.env.NULLCLAW_TOKEN || '';

// Disable CSRF for webhook
export const config = {
  csrf: {
    checkOrigin: false
  }
};

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.formData();
  const from = body.get('From') as string;
  const messageBody = body.get('Body') as string;

  if (!from || !messageBody) {
    return json({ error: 'missing fields' }, { status: 400 });
  }

  // Save incoming user message
  await db.insert(messages).values({
    channel: 'whatsapp',
    sender_id: from,
    role: 'user',
    content: messageBody,
    timestamp: Math.floor(Date.now() / 1000)
  });

  // Call NullClaw gateway for AI response
  const response = await fetch(`${GATEWAY_URL}/v1/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${BEARER_TOKEN}`
    },
    body: JSON.stringify({
      model: 'default',
      messages: [
        { role: 'user', content: messageBody }
      ]
    })
  });

  let aiReply = 'Sorry, I could not process your request.';
  
  if (response.ok) {
    const data = await response.json();
    aiReply = data.choices?.[0]?.message?.content || aiReply;
  }

  // Save AI reply
  await db.insert(messages).values({
    channel: 'whatsapp',
    sender_id: from,
    role: 'assistant',
    content: aiReply,
    timestamp: Math.floor(Date.now() / 1000)
  });

  // Send reply via Twilio
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>${aiReply}</Message>
</Response>`;

  return new Response(twiml, {
    headers: { 'Content-Type': 'text/xml' }
  });
};
