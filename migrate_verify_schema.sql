-- Migration script for importing real CSV data
-- Run this on the Contabo MySQL server: mysql -u longhorn -p3577 longhorn < migrate_real_data.sql

-- Step 1: Check current state of tables
SELECT '=== Current counts ===' AS info;
SELECT COUNT(*) as users_count FROM users;
SELECT COUNT(*) as schools_count FROM schools;
SELECT COUNT(*) as school_sales_count FROM school_sales;
SELECT COUNT(*) as opportunity_activities_count FROM opportunity_activities;

-- Step 2: Show columns for each table to verify schema
SELECT '=== Schools columns ===' AS info;
SHOW COLUMNS FROM schools;

SELECT '=== School_sales columns ===' AS info;
SHOW COLUMNS FROM school_sales;

SELECT '=== Opportunity_activities columns ===' AS info;
SHOW COLUMNS FROM opportunity_activities;

SELECT '=== Users columns ===' AS info;
SHOW COLUMNS FROM users;
