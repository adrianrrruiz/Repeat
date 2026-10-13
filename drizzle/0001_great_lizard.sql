CREATE TABLE `operation_receipts` (
	`user_id` text NOT NULL,
	`request_id` text NOT NULL,
	`created_at` text NOT NULL,
	PRIMARY KEY(`user_id`, `request_id`)
);
