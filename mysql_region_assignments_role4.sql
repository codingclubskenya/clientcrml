-- MySQL Migration: Grant role 4 (agent) permission to assign regions
-- Compatible with MySQL 8.0+
-- Note: MySQL doesn't have RLS policies like PostgreSQL.
-- Access control must be enforced at the application layer (API/Flutter).

-- =========================================================
-- TABLE: region_assignments (if not exists)
-- =========================================================
CREATE TABLE IF NOT EXISTS `region_assignments` (
    `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    `user_id` CHAR(36) NOT NULL,
    `region_id` CHAR(36) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_region_assignments_user_region` (`user_id`, `region_id`),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`region_id`) REFERENCES `regions`(`id`) ON DELETE CASCADE
);

-- =========================================================
-- TABLE: regions (if not exists)
-- =========================================================
CREATE TABLE IF NOT EXISTS `regions` (
    `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    `region` TEXT NOT NULL,
    `sub_region` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =========================================================
-- APPLICATION-LEVEL ACCESS CONTROL GUIDE
-- =========================================================
/*
In PostgreSQL/Supabase, these RLS policies were:
1. region_assignments - manage (insert/update/delete) for roles <= 4
2. region_assignments - select for roles <= 4 or own assignments
3. regions - manage for roles <= 4
4. route_plans - view for assigned user, null assigned, roles <= 2, or roles <= 4 in same region
5. route_plans - manage for roles <= 2, or roles <= 4 with assigned_to IS NULL, or roles <= 4 in same region
6. tasks - manage for roles <= 2, own tasks, or roles <= 4 in same region

In MySQL, you must enforce these in your API layer (api/index.js):

Example middleware helper for role checks:
```javascript
function canManageRegionAssignments(user) {
  return user && user.role <= 4; // admin(1), sales_manager(2), bas(3), agent(4)
}

function canViewRegionAssignments(user, targetUserId) {
  if (!user) return false;
  if (user.id === targetUserId) return true;
  return user.role <= 4;
}

function canManageRegion(user) {
  return user && user.role <= 4;
}

function canViewRoutePlan(user, routePlan) {
  if (!user) return false;
  if (routePlan.assigned_to === user.id) return true;
  if (routePlan.assigned_to === null) return true;
  if (user.role <= 2) return true;
  if (user.role <= 4) {
    // Check if assigned_to is role 4/5 in same region
    // Requires joining users table
    return true; // Implement region check
  }
  return false;
}

function canManageRoutePlan(user, routePlan) {
  if (!user) return false;
  if (user.role <= 2) return true;
  if (user.role <= 4 && routePlan.assigned_to === null) return true;
  if (user.role <= 4) {
    // Check if assigned_to is role 4/5 in same region
    return true; // Implement region check
  }
  return false;
}

function canManageTask(user, task) {
  if (!user) return false;
  if (user.role <= 2) return true;
  if (task.assigned_to === user.id) return true;
  if (user.role <= 4) {
    // Check if assigned_to is role 4/5 in same region
    return true; // Implement region check
  }
  return false;
}
*/

-- =========================================================
-- RECOMMENDED INDEXES FOR PERFORMANCE
-- =========================================================
CREATE INDEX IF NOT EXISTS `idx_region_assignments_user` ON `region_assignments`(`user_id`);
CREATE INDEX IF NOT EXISTS `idx_region_assignments_region` ON `region_assignments`(`region_id`);

-- =========================================================
-- SAMPLE APPLICATION LOGIC FOR ROUTE PLANS
-- =========================================================
/*
When querying route_plans in MySQL API:

// For role 4 agent viewing route plans
SELECT rp.* FROM route_plans rp
JOIN users u ON u.id = rp.assigned_to
WHERE (rp.assigned_to = ? OR rp.assigned_to IS NULL)
   OR ? <= 2
   OR (? <= 4 AND rp.assigned_to IS NULL)
   OR (? <= 4 AND u.role IN (4, 5) AND LOWER(COALESCE(u.region, '')) = LOWER(COALESCE(?, '')))

Params: [userId, userRole, userRole, userRole, userRegion]

// For role 4 agent managing route plans
Similar WHERE clause for UPDATE/DELETE/INSERT permissions
*/