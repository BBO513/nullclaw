import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { db } from '$lib/db';
import { messages } from '$lib/db/schema';
import { eq, and, desc } from 'drizzle-orm';

export const GET: RequestHandler = async ({ url }) => {
  const channel = url.searchParams.get('channel');
  const sender = url.searchParams.get('sender');

  let query = db.select().from(messages);

  if (channel && sender) {
    query = query.where(
      and(
        eq(messages.channel, channel),
        eq(messages.sender_id, sender)
      )
    );
  } else if (channel) {
    query = query.where(eq(messages.channel, channel));
  } else if (sender) {
    query = query.where(eq(messages.sender_id, sender));
  }

  const result = await query.orderBy(desc(messages.timestamp));

  return json(result);
};

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  
  await db.insert(messages).values({
    channel: body.channel || 'web',
    sender_id: body.sender_id || 'web-user',
    role: body.role,
    content: body.content,
    timestamp: Math.floor(Date.now() / 1000)
  });

  return json({ success: true });
};
