-- DEHUS MySQL Unified Schema
-- This file contains the complete database structure and seed data converted for MySQL.

-- 1. DROP TABLES (for clean start)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS audit_events;
DROP TABLE IF EXISTS supervisor_notes;
DROP TABLE IF EXISTS supervisor_incidents;
DROP TABLE IF EXISTS supervisor_alerts;
DROP TABLE IF EXISTS geofence_events;
DROP TABLE IF EXISTS route_plans;
DROP TABLE IF EXISTS geofences;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS school_sales;
DROP TABLE IF EXISTS schools;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- 2. TABLES

CREATE TABLE users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255),
  full_name VARCHAR(255),
  phone VARCHAR(50),
  role INT NOT NULL DEFAULT 5,
  region VARCHAR(100),
  isSynced TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE schools (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(50) NOT NULL,
  county VARCHAR(100) NOT NULL,
  source VARCHAR(50) NOT NULL DEFAULT 'manual',
  external_place_id VARCHAR(255),
  external_vicinity TEXT,
  focusAreas JSON,
  book_category VARCHAR(100),
  dealer_type VARCHAR(100),
  shop_category VARCHAR(100),
  selected_product VARCHAR(100),
  partner_subtype VARCHAR(100),
  latitude DOUBLE,
  longitude DOUBLE,
  gps_accuracy_meters DOUBLE,
  photo_url TEXT,
  photo_path TEXT,
  captured_by VARCHAR(36),
  captured_at DATETIME,
  capture_status VARCHAR(50),
  contact_name VARCHAR(255),
  contact_phone VARCHAR(50),
  contact_title VARCHAR(100),
  feedback TEXT,
  notes TEXT,
  samples_left TEXT,
  sample_book VARCHAR(255),
  school_ownership VARCHAR(50),
  school_ownership_other VARCHAR(255),
  school_population INT,
  school_lifecycle_status VARCHAR(50),
  engagement_type VARCHAR(50),
  sample_proof_url TEXT,
  sample_proof_path TEXT,
  isSynced TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_schools_captured_by FOREIGN KEY (captured_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE tasks (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  target_role INT NOT NULL DEFAULT 2,
  due_at DATETIME,
  status VARCHAR(50) NOT NULL DEFAULT 'open',
  created_by VARCHAR(36),
  assigned_to VARCHAR(36),
  isSynced TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_tasks_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_tasks_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE geofences (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  region VARCHAR(100),
  coordinates JSON,
  assigned_to VARCHAR(36),
  created_by VARCHAR(36),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_geofences_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_geofences_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE route_plans (
  id VARCHAR(36) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  route_date DATE NOT NULL,
  assigned_to VARCHAR(36),
  school_ids JSON,
  notes TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'assigned',
  created_by VARCHAR(36),
  reviewed_by VARCHAR(36),
  reviewed_at DATETIME,
  review_note TEXT,
  isSynced TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_route_plans_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_route_plans_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_route_plans_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
);

-- 3. SEED DATA (Minimal)

INSERT INTO users (id, email, full_name, role) VALUES 
('admin-001', 'admin@dehus.com', 'System Admin', 1),
('agent-001', 'agent@dehus.com', 'Field Agent 1', 5);

INSERT INTO geofences (id, name, region, coordinates) VALUES
('geo-001', 'Nairobi Central', 'Nairobi', '[{"lat": -1.28, "lng": 36.82}]');

-- Note: In MySQL, JSON strings must be valid double-quoted JSON.
-- e.g. '[{"lat": -1.22, "lng": 36.76}]'
