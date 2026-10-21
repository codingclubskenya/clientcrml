-- =============================================================
-- DEHUS Migration: Add views, stored procedures, and functions
-- Target: Contabo MySQL (SSH tunnel via 127.0.0.1:3307)
-- =============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================
-- VIEWS
-- =============================================================

DROP VIEW IF EXISTS `v_agent_performance`;
CREATE VIEW `v_agent_performance` AS
  SELECT
    a.id AS agent_id,
    u.full_name AS agent_name,
    u.region,
    COUNT(DISTINCT a.id) AS total_assignments,
    COUNT(s.id) AS total_sales,
    COALESCE(SUM(s.expected_value), 0) AS total_pipeline_value,
    COALESCE(SUM(s.weighted_forecast), 0) AS weighted_forecast_value
  FROM users u
  LEFT JOIN school_sales s ON s.agent_id = u.id
  LEFT JOIN event_assignments a ON a.agent_id = u.id
  WHERE u.role = 4
  GROUP BY u.id, u.full_name, u.region;

DROP VIEW IF EXISTS `v_sales_pipeline`;
CREATE VIEW `v_sales_pipeline` AS
  SELECT
    s.id,
    s.school_id,
    s.agent_id,
    s.package_name,
    s.sale_status,
    s.expected_value,
    s.probability,
    s.weighted_forecast,
    s.risk_level,
    s.next_action,
    s.next_action_date,
    s.stage_updated_at,
    s.closed_at,
    u.full_name AS agent_name,
    u.region
  FROM school_sales s
  LEFT JOIN users u ON u.id = s.agent_id;

DROP VIEW IF EXISTS `v_route_plan_summary`;
CREATE VIEW `v_route_plan_summary` AS
  SELECT
    r.id,
    r.title,
    r.route_date,
    r.status,
    r.assigned_to,
    u.full_name AS assigned_to_name,
    JSON_LENGTH(r.school_ids) AS stop_count,
    r.created_at,
    r.updated_at
  FROM route_plans r
  LEFT JOIN users u ON u.id = r.assigned_to;

DROP VIEW IF EXISTS `v_supervisor_dashboard`;
CREATE VIEW `v_supervisor_dashboard` AS
  SELECT
    u.id AS user_id,
    u.full_name,
    u.region,
    u.role,
    COUNT(sa.id) AS active_sales,
    COUNT(v.id) AS visits_today,
    COUNT(si.id) AS samples_distributed,
    MAX(sa.updated_at) AS last_sale_update
  FROM users u
  LEFT JOIN school_sales sa ON sa.agent_id = u.id AND sa.sale_status NOT IN ('won', 'lost', 'dormant')
  LEFT JOIN school_visits v ON v.agent_id = u.id AND DATE(v.visited_at) = CURDATE()
  LEFT JOIN school_sample_distributions si ON si.agent_id = u.id AND DATE(si.distributed_at) = CURDATE()
  WHERE u.role IN (4, 5)
  GROUP BY u.id, u.full_name, u.region, u.role;

-- =============================================================
-- STORED FUNCTIONS
-- =============================================================

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

CREATE FUNCTION `fn_is_admin`(user_id CHAR(36)) RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN IF(v_role = 1, 1, 0);
END$$

CREATE FUNCTION `fn_is_manager_or_admin`(user_id CHAR(36)) RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN IF(v_role <= 3, 1, 0);
END$$

CREATE FUNCTION `fn_is_sales_manager`(user_id CHAR(36)) RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN IF(v_role <= 2, 1, 0);
END$$

CREATE FUNCTION `fn_current_user_role`(user_id CHAR(36)) RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_role INT;
  SELECT role INTO v_role FROM users WHERE id = user_id LIMIT 1;
  RETURN COALESCE(v_role, 5);
END$$

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

  SET v_order_id = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.id')), UUID());
  SET v_order_number = COALESCE(
    NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_order_json, '$.order_number')), ''),
    CONCAT('ORD-', DATE_FORMAT(v_now, '%Y%m%d%H%i%S'), '-', UPPER(LEFT(REPLACE(UUID(), '-', ''), 8)))
  );
  SET v_sale_id = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_sale_json, '$.id')), UUID());

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

CREATE PROCEDURE `sp_process_supervisor_alert_sla`()
MODIFIES SQL DATA
BEGIN
  UPDATE supervisor_alerts
  SET ack_sla_met = 0
  WHERE status = 'open'
    AND LOWER(COALESCE(severity, '')) = 'red'
    AND created_at <= DATE_SUB(NOW(), INTERVAL 15 MINUTE)
    AND COALESCE(ack_sla_met, 1) = 1;

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

CREATE PROCEDURE `sp_queue_supervisor_daily_digests`()
READS SQL DATA
MODIFIES SQL DATA
BEGIN
  DECLARE current_hour_min VARCHAR(5);
  SET current_hour_min = DATE_FORMAT(NOW(), '%H:%i');

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
            AND a.resolved_at >= DATE_SUB(DATE(NOW()), INTERVAL 0 DAY)
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
-- MIGRATION HELPERS (password reset support)
-- =============================================================

-- Columns already added to users table:
-- ALTER TABLE users ADD COLUMN reset_token VARCHAR(255) NULL;
-- ALTER TABLE users ADD COLUMN reset_token_expiry DATETIME NULL;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Migration completed successfully' AS message;
