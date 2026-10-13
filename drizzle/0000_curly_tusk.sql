CREATE TABLE `entries` (
	`user_id` text NOT NULL,
	`habit_id` text NOT NULL,
	`date` text NOT NULL,
	`value` real DEFAULT 0 NOT NULL,
	`checked` integer DEFAULT false NOT NULL,
	`note` text DEFAULT '' NOT NULL,
	`mood` integer,
	`updated_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `habit_id`, `date`)
);
--> statement-breakpoint
CREATE TABLE `habits` (
	`user_id` text NOT NULL,
	`id` text NOT NULL,
	`content` text NOT NULL,
	`updated_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `id`)
);
--> statement-breakpoint
CREATE TABLE `moods` (
	`user_id` text NOT NULL,
	`date` text NOT NULL,
	`mood` integer NOT NULL,
	`note` text DEFAULT '' NOT NULL,
	PRIMARY KEY(`user_id`, `date`)
);
