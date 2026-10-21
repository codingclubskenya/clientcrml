-- =============================================================
-- DEHUS MySQL Complete Schema
-- Converted from Supabase/PostgreSQL to MySQL 8.0+
-- =============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================
-- 1. USERS
-- =============================================================
CREATE TABLE IF NOT EXISTS `users` (
  `id` CHAR(36) PRIMARY KEY,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255),
  `full_name` VARCHAR(255),
  `phone` VARCHAR(50),
  `id_number` VARCHAR(100),
  `avatar_url` TEXT,
  `role` INT NOT NULL DEFAULT 5,
  `role_ref` VARCHAR(50),
  `region` VARCHAR(100),
  `sub_region` VARCHAR(100),
  `region_id` CHAR(36),
  `reset_token` VARCHAR(255),
  `reset_token_expiry` DATETIME,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_users_role_region` (`role`, `region`),
  INDEX `idx_users_role_ref` (`role_ref`),
  INDEX `idx_users_region_id` (`region_id`)
);

-- =============================================================
-- 2. REGIONS
-- =============================================================
CREATE TABLE IF NOT EXISTS `regions` (
  `id` CHAR(36) PRIMARY KEY,
  `region` TEXT NOT NULL,
  `sub_region` TEXT,
  `counties` TEXT,
  `assigned_to` CHAR(36),
  `supervisor_id` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_regions_supervisor_id` (`supervisor_id`),
  INDEX `idx_regions_assigned_to` (`assigned_to`)
);

-- =============================================================
-- 3. REGION_ASSIGNMENTS (many-to-many)
-- =============================================================
CREATE TABLE IF NOT EXISTS `region_assignments` (
  `id` CHAR(36) PRIMARY KEY,
  `region_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NOT NULL,
  `role` INT NOT NULL,
  `assigned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_region_assignments_user_region` (`user_id`, `region_id`),
  INDEX `idx_region_assignments_user_id` (`user_id`),
  INDEX `idx_region_assignments_region_role` (`region_id`, `role`),
  FOREIGN KEY (`region_id`) REFERENCES `regions`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 4. SCHOOLS
-- =============================================================
CREATE TABLE IF NOT EXISTS `schools` (
  `id` CHAR(36) PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `phone` VARCHAR(50) NOT NULL,
  `county` VARCHAR(100) NOT NULL,
  `source` VARCHAR(50) NOT NULL DEFAULT 'manual',
  `external_place_id` VARCHAR(255),
  `external_vicinity` TEXT,
  `focusAreas` JSON,
  `book_category` VARCHAR(100),
  `dealer_type` VARCHAR(100),
  `shop_category` VARCHAR(100),
  `selected_product` VARCHAR(100),
  `partner_subtype` VARCHAR(100),
  `latitude` DOUBLE,
  `longitude` DOUBLE,
  `gps_accuracy_meters` DOUBLE,
  `photo_url` TEXT,
  `photo_path` TEXT,
  `captured_by` CHAR(36),
  `captured_at` DATETIME,
  `capture_status` VARCHAR(100),
  `contact_name` VARCHAR(255),
  `contact_phone` VARCHAR(50),
  `contact_email` VARCHAR(255),
  `contact_title` VARCHAR(100),
  `feedback` TEXT,
  `notes` TEXT,
  `samples_left` TEXT,
  `sample_books` VARCHAR(255),
  `school_ownership` VARCHAR(50),
  `school_ownership_other` VARCHAR(255),
  `school_population` INT,
  `school_lifecycle_status` VARCHAR(50),
  `engagement_type` VARCHAR(50),
  `sample_proof_url` TEXT,
  `sample_proof_path` TEXT,
  `competitor_analysis` TEXT,
  `school_level` VARCHAR(100),
  `designation` VARCHAR(100),
  `projected_quantity` INT,
  `lead_score` INT DEFAULT 0,
  `learning_materials` JSON,
  `book_programs` JSON,
  `region_id` CHAR(36),
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_schools_external_place_id` (`external_place_id`),
  INDEX `idx_schools_captured_by` (`captured_by`),
  INDEX `idx_schools_competitor_analysis` (`competitor_analysis`),
  INDEX `idx_schools_school_level` (`school_level`),
  INDEX `idx_schools_region_id` (`region_id`),
  FOREIGN KEY (`captured_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`region_id`) REFERENCES `regions`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 5. TASKS
-- =============================================================
CREATE TABLE IF NOT EXISTS `tasks` (
  `id` CHAR(36) PRIMARY KEY,
  `title` TEXT NOT NULL,
  `description` TEXT,
  `target_role` INT NOT NULL DEFAULT 2,
  `due_at` DATETIME,
  `status` VARCHAR(50) NOT NULL DEFAULT 'open',
  `created_by` CHAR(36),
  `assigned_to` CHAR(36),
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_tasks_assigned_status_due` (`assigned_to`, `status`, `due_at`),
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 6. TASK_COMPLETION_EVIDENCE
-- =============================================================
CREATE TABLE IF NOT EXISTS `task_completion_evidence` (
  `id` CHAR(36) PRIMARY KEY,
  `task_id` CHAR(36) NOT NULL,
  `submitted_by` CHAR(36) NOT NULL,
  `gps_lat` DOUBLE,
  `gps_lng` DOUBLE,
  `proof_url` TEXT,
  `proof_type` VARCHAR(50),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`task_id`) REFERENCES `tasks`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`submitted_by`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 7. GEOFENCES
-- =============================================================
CREATE TABLE IF NOT EXISTS `geofences` (
  `id` CHAR(36) PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `description` TEXT,
  `region` VARCHAR(100),
  `coordinates` JSON NOT NULL DEFAULT (JSON_ARRAY()),
  `assigned_to` CHAR(36),
  `created_by` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_geofences_region_assigned` (`region`, `assigned_to`),
  FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 8. GEOFENCE_EVENTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `geofence_events` (
  `id` CHAR(36) PRIMARY KEY,
  `user_id` CHAR(36) NOT NULL,
  `geofence_id` CHAR(36),
  `event_type` TEXT NOT NULL,
  `region` VARCHAR(100),
  `lat` DOUBLE,
  `lng` DOUBLE,
  `reason` TEXT,
  `status` VARCHAR(50) NOT NULL DEFAULT 'open',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` DATETIME,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`geofence_id`) REFERENCES `geofences`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 9. ROUTE_PLANS
-- =============================================================
CREATE TABLE IF NOT EXISTS `route_plans` (
  `id` CHAR(36) PRIMARY KEY,
  `title` TEXT NOT NULL DEFAULT 'Route Plan',
  `route_date` DATE NOT NULL,
  `assigned_to` CHAR(36),
  `school_ids` JSON NOT NULL DEFAULT (JSON_ARRAY()),
  `notes` TEXT,
  `status` VARCHAR(50) NOT NULL DEFAULT 'assigned',
  `created_by` CHAR(36),
  `reviewed_by` CHAR(36),
  `reviewed_at` DATETIME,
  `review_note` TEXT,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_route_plans_assigned_date_status` (`assigned_to`, `route_date`, `status`),
  CONSTRAINT `route_plans_status_check` CHECK (`status` IN ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed')),
  FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`reviewed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 10. VISITATIONS (route plan checklist)
-- =============================================================
CREATE TABLE IF NOT EXISTS `visitations` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36),
  `assigned_to` CHAR(36),
  `visit_date` DATE,
  `status` TEXT DEFAULT 'pending',
  `notes` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_visitations_assigned_date` (`assigned_to`, `visit_date`),
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 11. SCHOOL_VISITS
-- =============================================================
CREATE TABLE IF NOT EXISTS `school_visits` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `outcome` TEXT,
  `notes` TEXT,
  `photo_url` TEXT,
  `photo_path` TEXT,
  `latitude` DOUBLE,
  `longitude` DOUBLE,
  `visit_status` VARCHAR(50) NOT NULL DEFAULT 'completed',
  `visited_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 12. SCHOOL_FOLLOW_UPS
-- =============================================================
CREATE TABLE IF NOT EXISTS `school_follow_ups` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `contact_person` VARCHAR(255),
  `next_step` TEXT,
  `due_at` DATETIME,
  `notes` TEXT,
  `follow_up_status` VARCHAR(50) NOT NULL DEFAULT 'open',
  `completed_at` DATETIME,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 13. SCHOOL_SALES (pipeline opportunities)
-- =============================================================
CREATE TABLE IF NOT EXISTS `school_sales` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `package_name` TEXT NOT NULL,
  `expected_value` DECIMAL(12,2),
  `notes` TEXT,
  `sale_status` VARCHAR(50) NOT NULL DEFAULT 'lead',
  `stage_contact_person` TEXT,
  `sample_quantity` INT,
  `quotation_reference` TEXT,
  `decision_owner` TEXT,
  `negotiation_topic` TEXT,
  `loss_reason` TEXT,
  `dormant_reason` TEXT,
  `stage_updated_at` DATETIME,
  `expected_close_date` DATE,
  `probability` INT NOT NULL DEFAULT 0,
  `closed_at` DATETIME,
  `next_action` TEXT,
  `next_action_date` DATE,
  `last_activity_at` DATETIME,
  `forecast_category` VARCHAR(50) DEFAULT 'pipeline',
  `risk_level` VARCHAR(20) DEFAULT 'low',
  `weighted_forecast` DECIMAL(12,2) DEFAULT 0,
  `stage_sla_due_at` DATETIME,
  `region_id` CHAR(36),
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `school_sales_status_check` CHECK (`sale_status` IN ('lead', 'contacted', 'meeting_scheduled', 'sample_issued', 'quotation_sent', 'decision_pending', 'negotiation', 'won', 'lost', 'dormant')),
  CONSTRAINT `school_sales_sample_qty_check` CHECK (`sample_quantity` IS NULL OR `sample_quantity` >= 0),
  CONSTRAINT `school_sales_prob_check` CHECK (`probability` >= 0 AND `probability` <= 100),
  INDEX `idx_school_sales_stage_sla_due_at` (`stage_sla_due_at`),
  INDEX `idx_school_sales_next_action_date` (`next_action_date`),
  INDEX `idx_school_sales_risk_level` (`risk_level`),
  INDEX `idx_school_sales_region_id` (`region_id`),
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`region_id`) REFERENCES `regions`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 14. OPPORTUNITY_ACTIVITIES
-- =============================================================
CREATE TABLE IF NOT EXISTS `opportunity_activities` (
  `id` CHAR(36) PRIMARY KEY,
  `opportunity_id` CHAR(36) NOT NULL,
  `school_id` CHAR(36),
  `actor_id` CHAR(36),
  `activity_type` TEXT NOT NULL,
  `activity_outcome` TEXT,
  `notes` TEXT,
  `next_action` TEXT,
  `next_action_date` DATE,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_opportunity_activities_opportunity` (`opportunity_id`, `created_at` DESC),
  FOREIGN KEY (`opportunity_id`) REFERENCES `school_sales`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`actor_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 15. PIPELINE_HISTORY
-- =============================================================
CREATE TABLE IF NOT EXISTS `pipeline_history` (
  `id` CHAR(36) PRIMARY KEY,
  `pipeline_id` CHAR(36) NOT NULL,
  `old_stage` TEXT,
  `new_stage` TEXT NOT NULL,
  `changed_by` CHAR(36),
  `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `notes` TEXT,
  INDEX `idx_pipeline_history_pipeline_id` (`pipeline_id`),
  INDEX `idx_pipeline_history_changed_at` (`changed_at` DESC),
  FOREIGN KEY (`pipeline_id`) REFERENCES `school_sales`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`changed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 16. SCHOOL_SAMPLE_DISTRIBUTIONS
-- =============================================================
CREATE TABLE IF NOT EXISTS `school_sample_distributions` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `sample_name` TEXT NOT NULL,
  `sample_category` TEXT,
  `client_type` TEXT,
  `quantity` INT NOT NULL DEFAULT 1,
  `returned_qty` INT NOT NULL DEFAULT 0,
  `stamped_receipt_url` TEXT,
  `stamped_receipt_path` TEXT,
  `notes` TEXT,
  `distributed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_sample_distributions_agent_school` (`agent_id`, `school_id`, `distributed_at` DESC),
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 17. SAMPLE_REQUESTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `sample_requests` (
  `id` CHAR(36) PRIMARY KEY,
  `request_code` TEXT NOT NULL UNIQUE,
  `school_id` CHAR(36),
  `client_type` TEXT,
  `requested_by` CHAR(36),
  `purpose` TEXT,
  `notes` TEXT,
  `status` TEXT NOT NULL DEFAULT 'PENDING',
  `rejection_reason` TEXT,
  `needed_by` DATETIME,
  `requested_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` DATETIME,
  `reviewed_by` CHAR(36),
  `items` JSON NOT NULL DEFAULT (JSON_ARRAY()),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`requested_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`reviewed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 18. DEBT_COLLECTIONS
-- =============================================================
CREATE TABLE IF NOT EXISTS `debt_collections` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36) NOT NULL,
  `collected_by` CHAR(36),
  `amount` DECIMAL(12,2) NOT NULL,
  `payment_method` VARCHAR(50) NOT NULL DEFAULT 'cash',
  `payment_reference` TEXT,
  `notes` TEXT,
  `collected_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `debt_collections_amount_check` CHECK (`amount` > 0),
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`collected_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 19. CATALOG_ITEMS
-- =============================================================
CREATE TABLE IF NOT EXISTS `catalog_items` (
  `id` CHAR(36) PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `category` TEXT,
  `sku` VARCHAR(100) NOT NULL UNIQUE,
  `item_type` VARCHAR(50) NOT NULL DEFAULT 'sale',
  `unit_price` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `stock_qty` INT NOT NULL DEFAULT 0,
  `description` TEXT,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_by` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Extended book/school-item metadata
  `supplier_id` CHAR(36),
  `supplier_name` VARCHAR(255),
  `barcode` VARCHAR(100),
  `wholesale_price` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `unit` VARCHAR(50) NOT NULL DEFAULT 'pieces',
  `min_stock` INT NOT NULL DEFAULT 0,
  `max_stock` INT NOT NULL DEFAULT 0,
  `image_url` TEXT,
  `author` VARCHAR(255),
  `publisher` VARCHAR(255),
  `isbn` VARCHAR(100),
  `edition` VARCHAR(100),
  `grade_level` VARCHAR(100),
  `subject` VARCHAR(255),
  `language` VARCHAR(100),
  `page_count` INT,
  INDEX `idx_catalog_items_category` (`category`),
  INDEX `idx_catalog_items_supplier` (`supplier_id`),
  INDEX `idx_catalog_items_isbn` (`isbn`),
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 20. ORDERS
-- =============================================================
CREATE TABLE IF NOT EXISTS `orders` (
  `id` CHAR(36) PRIMARY KEY,
  `school_id` CHAR(36),
  `school_name` TEXT NOT NULL,
  `school_phone` VARCHAR(50),
  `agent_id` CHAR(36),
  `order_number` TEXT NOT NULL UNIQUE,
  `payment_method` VARCHAR(50) NOT NULL DEFAULT 'cash',
  `payment_reference` TEXT,
  `checkout_amount` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `status` VARCHAR(50) NOT NULL DEFAULT 'pending',
  `notes` TEXT,
  `submitted_at` DATETIME,
  `approved_at` DATETIME,
  `region_id` CHAR(36),
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_orders_agent_status` (`agent_id`, `status`, `created_at` DESC),
  INDEX `idx_orders_region_id` (`region_id`),
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`region_id`) REFERENCES `regions`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 21. ORDER_ITEMS
-- =============================================================
CREATE TABLE IF NOT EXISTS `order_items` (
  `id` CHAR(36) PRIMARY KEY,
  `order_id` CHAR(36) NOT NULL,
  `product_name` TEXT NOT NULL,
  `category` TEXT,
  `sku` TEXT,
  `quantity` INT NOT NULL DEFAULT 1,
  `unit_price` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `line_total` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `notes` TEXT,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 22. MESSAGES
-- =============================================================
CREATE TABLE IF NOT EXISTS `messages` (
  `id` CHAR(36) PRIMARY KEY,
  `sender_id` CHAR(36) NOT NULL,
  `recipient_id` CHAR(36) NOT NULL,
  `subject` TEXT NOT NULL,
  `body` TEXT NOT NULL,
  `related_school_id` CHAR(36),
  `related_task_id` CHAR(36),
  `is_read` TINYINT(1) NOT NULL DEFAULT 0,
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_messages_sender_recipient` (`sender_id`, `recipient_id`),
  FOREIGN KEY (`sender_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`recipient_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`related_school_id`) REFERENCES `schools`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`related_task_id`) REFERENCES `tasks`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 23. CONSIGNMENTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `consignments` (
  `consignment_id` VARCHAR(50) PRIMARY KEY,
  `business_associate_id` CHAR(36) NOT NULL,
  `business_associate_name` TEXT NOT NULL,
  `status` VARCHAR(50) NOT NULL DEFAULT 'pending',
  `notes` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `consignments_status_chk` CHECK (`status` IN ('pending', 'active', 'completed', 'cancelled')),
  INDEX `idx_consignments_ba` (`business_associate_id`),
  INDEX `idx_consignments_status` (`status`),
  FOREIGN KEY (`business_associate_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 24. CONSIGNMENT_ITEMS
-- =============================================================
CREATE TABLE IF NOT EXISTS `consignment_items` (
  `id` CHAR(36) PRIMARY KEY,
  `consignment_id` VARCHAR(50) NOT NULL,
  `product_id` CHAR(36) NOT NULL,
  `units_to_assign` INT NOT NULL,
  `units_sold` INT NOT NULL DEFAULT 0,
  `unit_price` DECIMAL(12,2) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uq_consignment_items_product` (`consignment_id`, `product_id`),
  INDEX `idx_consignment_items_product` (`product_id`),
  CONSTRAINT `consignment_items_units_chk` CHECK (`units_sold` <= `units_to_assign`),
  FOREIGN KEY (`consignment_id`) REFERENCES `consignments`(`consignment_id`) ON DELETE CASCADE,
  FOREIGN KEY (`product_id`) REFERENCES `catalog_items`(`id`) ON DELETE RESTRICT
);

-- =============================================================
-- 25. EVENTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `events` (
  `id` CHAR(36) PRIMARY KEY,
  `name` TEXT NOT NULL,
  `event_type` TEXT,
  `organization` TEXT,
  `venue` TEXT,
  `region` VARCHAR(100),
  `subregion` VARCHAR(100),
  `start_at` DATETIME,
  `end_at` DATETIME,
  `expected_attendance` INT,
  `budget` DECIMAL(12,2),
  `objectives` TEXT,
  `products` JSON DEFAULT (JSON_ARRAY()),
  `notes` TEXT,
  `status` VARCHAR(50) NOT NULL DEFAULT 'scheduled',
  `created_by` CHAR(36),
  `isSynced` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =============================================================
-- 26. EVENT_ASSIGNMENTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_assignments` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36) NOT NULL,
  `assigned_by` CHAR(36),
  `schedule` JSON DEFAULT (JSON_OBJECT()),
  `products` JSON DEFAULT (JSON_ARRAY()),
  `samples` JSON DEFAULT (JSON_ARRAY()),
  `marketing_materials` JSON DEFAULT (JSON_ARRAY()),
  `targets` JSON DEFAULT (JSON_OBJECT()),
  `notes` TEXT,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_event_assignments_event_agent` (`event_id`, `agent_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`assigned_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 27. EVENT_CHECKINS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_checkins` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36) NOT NULL,
  `checkin_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gps_lat` DOUBLE,
  `gps_lng` DOUBLE,
  `geofence_verified` TINYINT(1) DEFAULT 0,
  `qr_verified` TINYINT(1) DEFAULT 0,
  `selfie_url` TEXT,
  `checkin_type` VARCHAR(50) NOT NULL DEFAULT 'checkin',
  `location_text` TEXT,
  `notes` TEXT,
  INDEX `idx_event_checkins_event_agent` (`event_id`, `agent_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 28. EVENT_TASKS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_tasks` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `title` TEXT NOT NULL,
  `description` TEXT,
  `required` TINYINT(1) NOT NULL DEFAULT 1,
  `completed` TINYINT(1) NOT NULL DEFAULT 0,
  `completed_by` CHAR(36),
  `completed_at` DATETIME,
  `evidence_url` TEXT,
  `sort_order` INT DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_event_tasks_event_completed` (`event_id`, `completed`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`completed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 29. EVENT_LEADS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_leads` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `lead_name` TEXT,
  `school_id` CHAR(36),
  `phone` VARCHAR(50),
  `email` VARCHAR(255),
  `interested_products` JSON DEFAULT (JSON_ARRAY()),
  `purchase_timeline` TEXT,
  `notes` TEXT,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_event_leads_event_agent` (`event_id`, `agent_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 30. EVENT_ORDERS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_orders` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `order_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_event_orders_event` (`event_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 31. EVENT_SALES
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_sales` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `product_id` CHAR(36),
  `agent_id` CHAR(36),
  `quantity` INT NOT NULL DEFAULT 1,
  `amount` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `payment_method` VARCHAR(50) NOT NULL DEFAULT 'cash',
  `notes` TEXT,
  `sold_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `consignment_id` VARCHAR(50),
  `consignment_item_id` CHAR(36),
  INDEX `idx_event_sales_event` (`event_id`),
  INDEX `idx_event_sales_agent` (`agent_id`),
  INDEX `idx_event_sales_consignment` (`consignment_id`, `consignment_item_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`product_id`) REFERENCES `catalog_items`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`consignment_id`) REFERENCES `consignments`(`consignment_id`) ON DELETE SET NULL,
  FOREIGN KEY (`consignment_item_id`) REFERENCES `consignment_items`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 32. EVENT_SAMPLES
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_samples` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `product_id` CHAR(36),
  `quantity` INT NOT NULL DEFAULT 0,
  `recipient` TEXT,
  `recipient_signature` TEXT,
  `distributed_by` CHAR(36),
  `distributed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `notes` TEXT,
  INDEX `idx_event_samples_event_prod` (`event_id`, `product_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`product_id`) REFERENCES `catalog_items`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`distributed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 33. EVENT_PHOTOS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_photos` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `agent_id` CHAR(36),
  `photo_url` TEXT,
  `photo_path` TEXT,
  `photo_type` TEXT,
  `caption` TEXT,
  `uploaded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_event_photos_event` (`event_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`agent_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 34. EVENT_EXPENSES
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_expenses` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `submitted_by` CHAR(36),
  `expense_type` TEXT,
  `amount` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `currency` VARCHAR(10) DEFAULT 'KES',
  `receipt_url` TEXT,
  `status` VARCHAR(50) NOT NULL DEFAULT 'pending',
  `approved_by` CHAR(36),
  `approved_at` DATETIME,
  `notes` TEXT,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_event_expenses_event_status` (`event_id`, `status`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`submitted_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`approved_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 35. EVENT_REPORTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `event_reports` (
  `id` CHAR(36) PRIMARY KEY,
  `event_id` CHAR(36) NOT NULL,
  `created_by` CHAR(36),
  `summary` TEXT,
  `attendance_count` INT DEFAULT 0,
  `visitors_count` INT DEFAULT 0,
  `schools_count` INT DEFAULT 0,
  `qualified_leads_count` INT DEFAULT 0,
  `orders_count` INT DEFAULT 0,
  `revenue` DECIMAL(14,2) DEFAULT 0,
  `photos` JSON DEFAULT (JSON_ARRAY()),
  `gps_logs` JSON DEFAULT (JSON_ARRAY()),
  `expenses_summary` JSON DEFAULT (JSON_OBJECT()),
  `products_sold` JSON DEFAULT (JSON_ARRAY()),
  `challenges` TEXT,
  `recommendations` TEXT,
  `exported_pdf_url` TEXT,
  `exported_xlsx_url` TEXT,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_event_reports_event_id` (`event_id`),
  INDEX `idx_event_reports_event` (`event_id`),
  FOREIGN KEY (`event_id`) REFERENCES `events`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 36. SUPERVISOR_ALERTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `supervisor_alerts` (
  `id` CHAR(36) PRIMARY KEY,
  `user_id` CHAR(36) NOT NULL,
  `region` VARCHAR(100),
  `alert_type` TEXT NOT NULL,
  `severity` VARCHAR(20) NOT NULL DEFAULT 'amber',
  `status` VARCHAR(50) NOT NULL DEFAULT 'open',
  `message` TEXT,
  `acked_at` DATETIME,
  `resolved_at` DATETIME,
  `ack_sla_met` TINYINT(1) DEFAULT 0,
  `resolve_sla_met` TINYINT(1) DEFAULT 0,
  `escalated_to_admin` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_supervisor_alerts_status_created` (`status`, `created_at`),
  INDEX `idx_supervisor_alerts_region` (`region`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 37. SUPERVISOR_INCIDENTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `supervisor_incidents` (
  `id` CHAR(36) PRIMARY KEY,
  `user_id` CHAR(36) NOT NULL,
  `region` VARCHAR(100),
  `incident_type` TEXT NOT NULL,
  `severity` VARCHAR(20) NOT NULL DEFAULT 'high',
  `status` VARCHAR(50) NOT NULL DEFAULT 'open',
  `notes` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 38. SUPERVISOR_NOTES
-- =============================================================
CREATE TABLE IF NOT EXISTS `supervisor_notes` (
  `id` CHAR(36) PRIMARY KEY,
  `supervisor_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NOT NULL,
  `region` VARCHAR(100),
  `context_type` TEXT,
  `context_id` CHAR(36),
  `note` TEXT NOT NULL,
  `follow_up_at` DATETIME,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`supervisor_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 39. SUPERVISOR_NOTIFICATIONS
-- =============================================================
CREATE TABLE IF NOT EXISTS `supervisor_notifications` (
  `id` CHAR(36) PRIMARY KEY,
  `supervisor_id` CHAR(36) NOT NULL,
  `region` VARCHAR(100),
  `notification_type` TEXT NOT NULL,
  `title` TEXT NOT NULL,
  `body` TEXT NOT NULL,
  `payload` JSON NOT NULL DEFAULT (JSON_OBJECT()),
  `scheduled_for` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `sent_at` DATETIME,
  `read_at` DATETIME,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_supervisor_notifications_supervisor_scheduled` (`supervisor_id`, `scheduled_for`),
  INDEX `idx_supervisor_notifications_read_at` (`read_at`),
  FOREIGN KEY (`supervisor_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 40. AUDIT_EVENTS
-- =============================================================
CREATE TABLE IF NOT EXISTS `audit_events` (
  `id` CHAR(36) PRIMARY KEY,
  `actor_id` CHAR(36),
  `action` TEXT NOT NULL,
  `entity_type` TEXT NOT NULL,
  `entity_id` TEXT NOT NULL,
  `region` VARCHAR(100),
  `before_data` JSON,
  `after_data` JSON,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`actor_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 41. TARGETS
-- =============================================================
CREATE TABLE IF NOT EXISTS `targets` (
  `id` CHAR(36) PRIMARY KEY,
  `scope` TEXT NOT NULL,
  `region_id` CHAR(36),
  `sub_region` TEXT,
  `assigned_to` CHAR(36),
  `target_type` TEXT NOT NULL,
  `target_period` TEXT NOT NULL,
  `target_data` JSON NOT NULL DEFAULT (JSON_OBJECT()),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `targets_scope_check` CHECK (`scope` IN ('regional', 'agent', 'business_advisor', 'sales_rep')),
  CONSTRAINT `targets_type_check` CHECK (`target_type` IN ('product_sales', 'customer_visits', 'collections', 'new_customers', 'sample_distribution', 'consignment')),
  CONSTRAINT `targets_period_check` CHECK (`target_period` IN ('daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'ytd')),
  INDEX `idx_targets_scope_type` (`scope`, `target_type`),
  INDEX `idx_targets_assigned_to` (`assigned_to`),
  INDEX `idx_targets_region_id` (`region_id`),
  FOREIGN KEY (`region_id`) REFERENCES `regions`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 42. SOCIAL_CONVERSATIONS
-- =============================================================
CREATE TABLE IF NOT EXISTS `social_conversations` (
  `id` CHAR(36) PRIMARY KEY,
  `channel` TEXT NOT NULL,
  `external_conversation_id` TEXT NOT NULL,
  `participant_display` TEXT,
  `participant_phone` TEXT,
  `last_message_preview` TEXT,
  `last_message_at` DATETIME,
  `raw_payload` JSON NOT NULL DEFAULT (JSON_OBJECT()),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `social_channel_check` CHECK (`channel` IN ('facebook', 'whatsapp')),
  UNIQUE KEY `uk_social_conv_channel_external` (`channel`, `external_conversation_id`)
);

-- =============================================================
-- 43. SOCIAL_MESSAGES
-- =============================================================
CREATE TABLE IF NOT EXISTS `social_messages` (
  `id` CHAR(36) PRIMARY KEY,
  `conversation_id` CHAR(36) NOT NULL,
  `channel` TEXT NOT NULL,
  `external_message_id` TEXT NOT NULL,
  `sender_name` TEXT,
  `sender_id` TEXT,
  `body` TEXT,
  `sent_at` DATETIME,
  `raw_payload` JSON NOT NULL DEFAULT (JSON_OBJECT()),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `social_msg_channel_check` CHECK (`channel` IN ('facebook', 'whatsapp')),
  UNIQUE KEY `uk_social_msg_channel_external` (`channel`, `external_message_id`),
  FOREIGN KEY (`conversation_id`) REFERENCES `social_conversations`(`id`) ON DELETE CASCADE
);

-- =============================================================
-- 44. PROJECT_FORMS
-- =============================================================
CREATE TABLE IF NOT EXISTS `project_forms` (
  `id` CHAR(36) PRIMARY KEY,
  `title` TEXT NOT NULL,
  `description` TEXT NOT NULL DEFAULT '',
  `questions` JSON NOT NULL DEFAULT (JSON_ARRAY()),
  `assigned_user_ids` JSON NOT NULL DEFAULT (JSON_ARRAY()),
  `published_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` CHAR(36),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_project_forms_published_at` (`published_at` DESC),
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =============================================================
-- 45. PROJECT_FORM_RESPONSES
-- =============================================================
CREATE TABLE IF NOT EXISTS `project_form_responses` (
  `id` CHAR(36) PRIMARY KEY,
  `form_id` CHAR(36) NOT NULL,
  `form_title` TEXT NOT NULL,
  `respondent_id` CHAR(36) NOT NULL,
  `answers` JSON NOT NULL DEFAULT (JSON_OBJECT()),
  `submitted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_project_form_responses_form_title` (`form_title`),
  INDEX `idx_project_form_responses_submitted_at` (`submitted_at` DESC),
  FOREIGN KEY (`form_id`) REFERENCES `project_forms`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`respondent_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================
-- VIEWS
-- =============================================================

-- Role 5 Performance Scorecard
CREATE OR REPLACE VIEW `role5_performance_scorecard` AS
SELECT
  u.id AS user_id,
  u.full_name,
  u.region,
  COUNT(DISTINCT t.id) AS total_tasks,
  COUNT(DISTINCT CASE WHEN t.status = 'closed' THEN t.id END) AS completed_tasks,
  COUNT(DISTINCT r.id) AS total_routes,
  COUNT(DISTINCT CASE WHEN r.status = 'completed' THEN r.id END) AS completed_routes,
  COUNT(DISTINCT sv.id) AS total_visits
FROM users u
LEFT JOIN tasks t ON t.assigned_to = u.id AND t.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
LEFT JOIN route_plans r ON r.assigned_to = u.id AND r.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
LEFT JOIN school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
WHERE u.role = 5
GROUP BY u.id, u.full_name, u.region;

-- Agent Sample ROI View
CREATE OR REPLACE VIEW `v_agent_sample_roi` AS
SELECT
  u.id AS agent_id,
  COALESCE(u.full_name, u.email, 'Unknown User') AS agent_name,
  COALESCE(ss.samples_given, 0) AS samples_given,
  COALESCE(rs.revenue_earned, 0) AS revenue_earned,
  COALESCE(ws.won_value, 0) AS won_value
FROM users u
LEFT JOIN (
  SELECT agent_id, COUNT(*) AS samples_given, COUNT(DISTINCT school_id) AS schools_reached
  FROM school_sample_distributions WHERE agent_id IS NOT NULL GROUP BY agent_id
) ss ON ss.agent_id = u.id
LEFT JOIN (
  SELECT agent_id, SUM(CASE WHEN status IN ('approved', 'paid', 'completed') THEN checkout_amount ELSE 0 END) AS revenue_earned
  FROM orders WHERE agent_id IS NOT NULL GROUP BY agent_id
) rs ON rs.agent_id = u.id
LEFT JOIN (
  SELECT agent_id, SUM(CASE WHEN sale_status = 'won' THEN expected_value ELSE 0 END) AS won_value
  FROM school_sales WHERE agent_id IS NOT NULL GROUP BY agent_id
) ws ON ws.agent_id = u.id
WHERE u.role IN (4, 5);

-- =============================================================
-- STORED PROCEDURES (MySQL equivalents of PostgreSQL functions)
-- =============================================================

DELIMITER $$

-- Role ID from text
CREATE FUNCTION `fn_role_id_from_text`(role_text TEXT) RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_result INT DEFAULT 5;
  IF role_text IS NULL OR TRIM(role_text) = '' THEN
    RETURN 5;
  END IF;
  CASE LOWER(TRIM(role_text))
    WHEN 'admin' THEN SET v_result = 1;
    WHEN 'sales manager' THEN SET v_result = 2;
    WHEN 'bas' THEN SET v_result = 3;
    WHEN 'agent' THEN SET v_result = 4;
    WHEN 'grounds person' THEN SET v_result = 5;
    ELSE
      BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN SET v_result = 5; END;
        SET v_result = CAST(role_text AS UNSIGNED);
      END;
  END CASE;
  RETURN v_result;
END$$

-- Check if current user is admin
CREATE FUNCTION `fn_is_admin`(user_id CHAR(36)) RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN IF(v_role = 1, 1, 0);
END$$

-- Check if current user is manager or admin
CREATE FUNCTION `fn_is_manager_or_admin`(user_id CHAR(36)) RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN IF(v_role <= 3, 1, 0);
END$$

-- Check if current user is sales manager
CREATE FUNCTION `fn_is_sales_manager`(user_id CHAR(36)) RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN IF(v_role <= 2, 1, 0);
END$$

-- Get current user role
CREATE FUNCTION `fn_current_user_role`(user_id CHAR(36)) RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN COALESCE(v_role, 5);
END$$

-- Generate overdue followup alerts
CREATE PROCEDURE `sp_generate_overdue_followup_alerts`()
MODIFIES SQL DATA
BEGIN
  INSERT INTO supervisor_alerts (user_id, region, alert_type, severity, status, message, created_at)
  SELECT
    s.agent_id,
    u.region,
    'overdue_followup',
    'amber',
    'open',
    'Opportunity follow-up is overdue for assigned Role 5 user.',
    NOW()
  FROM school_sales s
  JOIN users u ON u.id = s.agent_id
  WHERE u.role = 5
    AND s.next_action_date IS NOT NULL
    AND s.next_action_date < CURDATE()
    AND LOWER(COALESCE(s.sale_status, '')) NOT IN ('won', 'lost', 'dormant')
    AND NOT EXISTS (
      SELECT 1 FROM supervisor_alerts a
      WHERE a.user_id = s.agent_id
        AND a.alert_type = 'overdue_followup'
        AND a.status = 'open'
        AND a.created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    );
END$$

-- Create school sale checkout (MySQL equivalent of create_school_sale_checkout)
CREATE PROCEDURE `sp_create_school_sale_checkout`(
  IN p_order_json JSON,
  IN p_items_json JSON,
  IN p_sale_json JSON
)
READS SQL DATA
MODIFIES SQL DATA
BEGIN
  DECLARE v_now DATETIME DEFAULT NOW();
  DECLARE v_order_id CHAR(36);
  DECLARE v_order_number TEXT;
  DECLARE v_sale_id CHAR(36);
  DECLARE i INT DEFAULT 0;
  DECLARE item_count INT DEFAULT 0;
  DECLARE v_item JSON;

  -- Generate order ID
  SET v_order_id = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.id')), UUID());

  -- Generate order number
  SET v_order_number = COALESCE(
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.order_number')), ''),
    CONCAT('ORD-', DATE_FORMAT(v_now, '%Y%m%d%H%i%S'), '-', UPPER(LEFT(REPLACE(UUID(), '-', ''), 8)))
  );

  -- Generate sale ID
  SET v_sale_id = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.id')), UUID());

  -- Insert order
  INSERT INTO orders (
    id, school_id, school_name, school_phone, agent_id, order_number,
    payment_method, payment_reference, checkout_amount, status, notes,
    submitted_at, approved_at, isSynced, created_at, updated_at
  ) VALUES (
    v_order_id,
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.school_id')), ''),
    COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.school_name')), ''), 'School'),
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.school_phone')), ''),
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.agent_id')), ''),
    v_order_number,
    COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.payment_method')), ''), 'cash'),
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.payment_reference')), ''),
    COALESCE(JSON_EXTRACT(p_order_json, '$.checkout_amount'), 0),
    COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.status')), ''), 'pending'),
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.notes')), ''),
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.submitted_at')), CAST(v_now AS CHAR)),
    JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.approved_at')),
    COALESCE(JSON_EXTRACT(p_order_json, '$.isSynced'), 0),
    v_now, v_now
  );

  -- Insert order items
  IF p_items_json IS NOT NULL THEN
    SET item_count = JSON_LENGTH(p_items_json);
    WHILE i < item_count DO
      SET v_item = JSON_EXTRACT(p_items_json, CONCAT('$[', i, ']'));
      INSERT INTO order_items (
        id, order_id, product_name, category, sku, quantity,
        unit_price, line_total, notes, isSynced, created_at, updated_at
      ) VALUES (
        COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(v_item, '$.id')), ''), UUID()),
        v_order_id,
        COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(v_item, '$.product_name')), ''), 'Item'),
        NULLIF(JSON_UNQUOTE(JSON_EXTRACT(v_item, '$.category')), ''),
        NULLIF(JSON_UNQUOTE(JSON_EXTRACT(v_item, '$.sku')), ''),
        COALESCE(JSON_EXTRACT(v_item, '$.quantity'), 1),
        COALESCE(JSON_EXTRACT(v_item, '$.unit_price'), 0),
        COALESCE(JSON_EXTRACT(v_item, '$.line_total'), 0),
        NULLIF(JSON_UNQUOTE(JSON_EXTRACT(v_item, '$.notes')), ''),
        COALESCE(JSON_EXTRACT(v_item, '$.isSynced'), 0),
        v_now, v_now
      );
      SET i = i + 1;
    END WHILE;
  END IF;

  -- Insert or update school sale
  INSERT INTO school_sales (
    id, school_id, agent_id, package_name, expected_value, notes,
    sale_status, stage_updated_at, expected_close_date, probability,
    closed_at, isSynced, created_at, updated_at
  ) VALUES (
    v_sale_id,
    COALESCE(
      NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.school_id')), ''),
      (SELECT school_id FROM orders WHERE id = v_order_id)
    ),
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.agent_id')), ''),
    COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.package_name')), ''), 'School Package'),
    COALESCE(JSON_EXTRACT(p_sale_json, '$.expected_value'),
      (SELECT checkout_amount FROM orders WHERE id = v_order_id)
    ),
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.notes')), ''),
    COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.sale_status')), ''), 'won'),
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.stage_updated_at')), CAST(v_now AS CHAR)),
    JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.expected_close_date')),
    COALESCE(JSON_EXTRACT(p_sale_json, '$.probability'), 100),
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.closed_at')), CAST(v_now AS CHAR)),
    COALESCE(JSON_EXTRACT(p_sale_json, '$.isSynced'), 0),
    v_now, v_now
  )
  ON DUPLICATE KEY UPDATE
    school_id = VALUES(school_id),
    agent_id = VALUES(agent_id),
    package_name = VALUES(package_name),
    expected_value = VALUES(expected_value),
    notes = VALUES(notes),
    sale_status = VALUES(sale_status),
    stage_updated_at = VALUES(stage_updated_at),
    expected_close_date = VALUES(expected_close_date),
    probability = VALUES(probability),
    closed_at = VALUES(closed_at),
    isSynced = VALUES(isSynced),
    updated_at = VALUES(updated_at);

  -- Update weighted_forecast and metrics
  UPDATE school_sales
  SET
    weighted_forecast = ROUND((expected_value * probability) / 100.0, 2),
    risk_level = CASE
      WHEN sale_status IN ('won', 'lost', 'dormant') THEN 'low'
      WHEN next_action_date IS NULL THEN 'high'
      WHEN next_action_date < CURDATE() THEN 'high'
      WHEN next_action_date <= DATE_ADD(CURDATE(), INTERVAL 1 DAY) THEN 'medium'
      ELSE 'low'
    END,
    next_action = COALESCE(NULLIF(TRIM(next_action), ''), 'Follow up call'),
    next_action_date = COALESCE(next_action_date, DATE_ADD(CURDATE(), INTERVAL 2 DAY))
  WHERE id = v_sale_id
    AND sale_status NOT IN ('won', 'lost', 'dormant');

END$$

-- Process supervisor alert SLA
CREATE PROCEDURE `sp_process_supervisor_alert_sla`()
MODIFIES SQL DATA
BEGIN
  -- Mark open red alerts older than 15 minutes as SLA-breached for ack
  UPDATE supervisor_alerts
  SET ack_sla_met = 0
  WHERE status = 'open'
    AND LOWER(COALESCE(severity, '')) = 'red'
    AND created_at <= DATE_SUB(NOW(), INTERVAL 15 MINUTE)
    AND COALESCE(ack_sla_met, 1) = 1;

  -- Escalate unresolved red alerts older than 2 hours
  INSERT INTO supervisor_notifications (
    supervisor_id, region, notification_type, title, body, payload, scheduled_for
  )
  SELECT
    u.id, u.region, 'escalation',
    'Escalated Red Alert',
    'A red alert is unresolved for over 2 hours and has been escalated.',
    JSON_OBJECT('alert_id', a.id, 'alert_type', a.alert_type, 'user_id', a.user_id),
    NOW()
  FROM supervisor_alerts a
  JOIN users u ON u.role = 3 AND LOWER(COALESCE(u.region, '')) = LOWER(COALESCE(a.region, ''))
  WHERE a.status = 'open'
    AND LOWER(COALESCE(a.severity, '')) = 'red'
    AND a.created_at <= DATE_SUB(NOW(), INTERVAL 2 HOUR)
    AND a.escalated_to_admin = 0;

  UPDATE supervisor_alerts
  SET escalated_to_admin = 1
  WHERE status = 'open'
    AND LOWER(COALESCE(severity, '')) = 'red'
    AND created_at <= DATE_SUB(NOW(), INTERVAL 2 HOUR)
    AND escalated_to_admin = 0;
END$$

-- Queue supervisor daily digests (morning at 07:00, evening at 18:00)
CREATE PROCEDURE `sp_queue_supervisor_daily_digests`()
READS SQL DATA
MODIFIES SQL DATA
BEGIN
  DECLARE current_hour_min VARCHAR(5);
  SET current_hour_min = DATE_FORMAT(NOW(), '%H:%i');

  -- Morning digest
  IF current_hour_min BETWEEN '07:00' AND '07:10' THEN
    INSERT INTO supervisor_notifications (
      supervisor_id, region, notification_type, title, body, payload, scheduled_for
    )
    SELECT
      s.id, s.region, 'daily_digest',
      'Morning Supervision Digest',
      'Start-of-day summary for your Role 5 region.',
      JSON_OBJECT(
        'open_alerts', (
          SELECT COUNT(*) FROM supervisor_alerts a
          WHERE LOWER(COALESCE(a.region, '')) = LOWER(COALESCE(s.region, ''))
            AND a.status = 'open'
        ),
        'overdue_tasks', (
          SELECT COUNT(*) FROM tasks t
          JOIN users u ON u.id = t.assigned_to
          WHERE u.role = 5
            AND LOWER(COALESCE(u.region, '')) = LOWER(COALESCE(s.region, ''))
            AND t.due_at < NOW()
            AND LOWER(COALESCE(t.status, '')) NOT IN ('closed', 'completed')
        )
      ),
      NOW()
    FROM users s WHERE s.role = 3;
  END IF;

  -- Evening digest
  IF current_hour_min BETWEEN '18:00' AND '18:10' THEN
    INSERT INTO supervisor_notifications (
      supervisor_id, region, notification_type, title, body, payload, scheduled_for
    )
    SELECT
      s.id, s.region, 'evening_summary',
      'Evening Supervision Summary',
      'End-of-day summary for Role 5 execution in your region.',
      JSON_OBJECT(
        'resolved_alerts', (
          SELECT COUNT(*) FROM supervisor_alerts a
          WHERE LOWER(COALESCE(a.region, '')) = LOWER(COALESCE(s.region, ''))
            AND a.status = 'resolved'
            AND a.resolved_at >= DATE_SUB(DATE(now()), INTERVAL 0 DAY)
        ),
        'completed_routes', (
          SELECT COUNT(*) FROM route_plans r
          JOIN users u ON u.id = r.assigned_to
          WHERE u.role = 5
            AND LOWER(COALESCE(u.region, '')) = LOWER(COALESCE(s.region, ''))
            AND LOWER(COALESCE(r.status, '')) = 'completed'
            AND r.route_date = CURDATE()
        )
      ),
      NOW()
    FROM users s WHERE s.role = 3;
  END IF;
END$$

DELIMITER ;

-- =============================================================
-- SEED DATA
-- =============================================================

INSERT IGNORE INTO users (id, email, full_name, role, region, password_hash, created_at, updated_at) VALUES
  ('11111111-1111-1111-1111-111111111111', 'faith.agent@example.com', 'Faith Agent', 4, 'Nairobi', '$2b$10$placeholder', NOW(), NOW()),
  ('22222222-aaaa-aaaa-aaaa-222222222222', 'manager.role2@example.com', 'Demo Sales Manager', 2, 'Nairobi', '$2b$10$placeholder', NOW(), NOW()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'grounds.role5@example.com', 'Grounds Role5', 5, 'Nyanza', '$2b$10$placeholder', NOW(), NOW());

INSERT IGNORE INTO schools (id, name, phone, county, focusAreas, book_category, latitude, longitude, capture_status, captured_by, captured_at, isSynced, created_at, updated_at) VALUES
  ('22222222-2222-2222-2222-222222222222', 'Nairobi Primary School', '0712345678', 'Nairobi', JSON_ARRAY('Mathematics', 'Science'), 'Book List', -1.2921, 36.8219, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', NOW() - INTERVAL 1 DAY, 1, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'Mombasa High School', '0723456789', 'Mombasa', JSON_ARRAY('Languages', 'Arts'), 'Book Fund', -4.0435, 39.6682, 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', NOW() - INTERVAL 1 DAY, 1, NOW(), NOW());

INSERT IGNORE INTO geofences (id, name, description, region, coordinates, assigned_to, created_at, updated_at) VALUES
  ('geo-001', 'Nairobi County Demo', 'Demo boundary for Nairobi county.', 'Nairobi', JSON_ARRAY(JSON_OBJECT('lat', -1.220, 'lng', 36.760)), '11111111-1111-1111-1111-111111111111', NOW(), NOW());

INSERT IGNORE INTO regions (id, region, sub_region, created_at, updated_at) VALUES
  ('region-001', 'Nairobi', 'West', NOW(), NOW()),
  ('region-002', 'Mombasa', 'Coast', NOW(), NOW());

INSERT IGNORE INTO region_assignments (id, region_id, user_id, role, assigned_at, updated_at) VALUES
  (UUID(), 'region-001', '11111111-1111-1111-1111-111111111111', 4, NOW(), NOW());
