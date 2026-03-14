CREATE TABLE `messages` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`channel` text NOT NULL,
	`sender_id` text NOT NULL,
	`role` text NOT NULL,
	`content` text NOT NULL,
	`timestamp` integer NOT NULL
);
