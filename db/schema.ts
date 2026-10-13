import { sqliteTable, text, real, integer, primaryKey } from 'drizzle-orm/sqlite-core';
export const habits=sqliteTable('habits',{userId:text('user_id').notNull(),id:text('id').notNull(),content:text('content').notNull(),updatedAt:text('updated_at').notNull()},t=>[primaryKey({columns:[t.userId,t.id]})]);
export const entries=sqliteTable('entries',{userId:text('user_id').notNull(),habitId:text('habit_id').notNull(),date:text('date').notNull(),value:real('value').notNull().default(0),checked:integer('checked',{mode:'boolean'}).notNull().default(false),note:text('note').notNull().default(''),mood:integer('mood'),updatedAt:text('updated_at').notNull()},t=>[primaryKey({columns:[t.userId,t.habitId,t.date]})]);
export const moods=sqliteTable('moods',{userId:text('user_id').notNull(),date:text('date').notNull(),mood:integer('mood').notNull(),note:text('note').notNull().default('')},t=>[primaryKey({columns:[t.userId,t.date]})]);

export const operationReceipts=sqliteTable('operation_receipts',{userId:text('user_id').notNull(),requestId:text('request_id').notNull(),createdAt:text('created_at').notNull()},t=>[primaryKey({columns:[t.userId,t.requestId]})]);
