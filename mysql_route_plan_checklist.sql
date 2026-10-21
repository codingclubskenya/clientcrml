-- MySQL Migration: Route Plan Checklist & Visitations
-- Compatible with MySQL 8.0+

-- =========================================================
-- TABLE: tasks
-- =========================================================
CREATE TABLE IF NOT EXISTS `tasks` (
    `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    `title` TEXT NOT NULL,
    `description` TEXT,
    `target_role` INT DEFAULT 2,
    `due_at` TIMESTAMP NULL,
    `status` TEXT DEFAULT 'open',
    `assigned_to` CHAR(36),
    `created_by` CHAR(36),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_tasks_assigned_status_due` (`assigned_to`, `status`, `due_at`)
);

-- =========================================================
-- TABLE: visitations (new table for route plan checklist)
-- =========================================================
CREATE TABLE IF NOT EXISTS `visitations` (
    `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    `school_id` CHAR(36),
    `assigned_to` CHAR(36),
    `visit_date` DATE,
    `status` TEXT DEFAULT 'pending',
    `notes` TEXT,
    `created_by` CHAR(36),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_visitations_assigned_date` (`assigned_to`, `visit_date`),
    FOREIGN KEY (`school_id`) REFERENCES `schools`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- =========================================================
-- TABLE: route_plans (updated with new columns)
-- =========================================================
CREATE TABLE IF NOT EXISTS `route_plans` (
    `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    `title` TEXT NOT NULL,
    `route_date` DATE NOT NULL,
    `assigned_to` CHAR(36),
    `school_ids` JSON NOT NULL DEFAULT (JSON_ARRAY()),
    `notes` TEXT,
    `status` TEXT NOT NULL DEFAULT 'assigned',
    `created_by` CHAR(36),
    `isSynced` BOOLEAN NOT NULL DEFAULT FALSE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_route_plans_assigned_date_status` (`assigned_to`, `route_date`, `status`),
    FOREIGN KEY (`assigned_to`) REFERENCES `users`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- Add helper columns for review workflows
ALTER TABLE `route_plans`
    ADD COLUMN IF NOT EXISTS `reviewed_by` CHAR(36),
    ADD COLUMN IF NOT EXISTS `reviewed_at` TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS `review_note` TEXT;

-- Add foreign key for reviewed_by
ALTER TABLE `route_plans`
    ADD CONSTRAINT `fk_route_plans_reviewed_by`
    FOREIGN KEY (`reviewed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL;

-- Status check constraint (MySQL 8.0.16+)
ALTER TABLE `route_plans`
    ADD CONSTRAINT `route_plans_status_check`
    CHECK (`status` IN ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed'));

-- =========================================================
-- Note: RLS policies are not available in MySQL
-- Access control must be enforced at application level
-- =========================================================