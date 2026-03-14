import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const messages = sqliteTable('messages', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  channel: text('channel').notNull(), // 'whatsapp' or 'web'
  sender_id: text('sender_id').notNull(), // phone number for WhatsApp, user ID for web
  role: text('role').notNull(), // 'user' or 'assistant'
  content: text('content').notNull(),
  timestamp: integer('timestamp').notNull()
});
