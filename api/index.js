const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { randomUUID, createHmac, pbkdf2Sync } = require("crypto");
require("dotenv").config();
const { DB_SCHEMA_PROMPT } = require("./schema_context");

const app = express();
const port = process.env.PORT || 3000;

const dbHost = process.env.DB_HOST || process.env.MYSQL_HOST || "localhost";
const dbUser = process.env.DB_USER || process.env.MYSQL_USER || "root";
const dbPassword = process.env.DB_PASSWORD || process.env.MYSQL_PASSWORD || "";
const dbName = process.env.DB_NAME || process.env.MYSQL_DATABASE || "";

const JWT_SECRET = process.env.JWT_SECRET || "dehus-secret-key-change-in-production";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";

if (!dbPassword || !dbName) {
  console.warn(
    "Warning: Database credentials not fully configured. Set DB_HOST, DB_USER, DB_PASSWORD, DB_NAME or Railway MySQL variables.",
  );
}

const pool = mysql.createPool({
  host: dbHost,
  user: dbUser,
  password: dbPassword,
  database: dbName,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

async function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "No token provided" });
  }
  const token = authHeader.split(" ")[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: "Invalid token" });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }
    next();
  };
}

// Auth endpoints use MySQL directly
const fs = require("fs");
const path = require("path");

app.use(cors());
app.use(express.json());

const UPLOAD_DIR = path.join(__dirname, "uploads");
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// Helper to build WHERE clause from filters
function buildWhereClause(filters) {
  let whereClause = "";
  const params = [];
  if (!filters || typeof filters !== "object") return { whereClause, params };

  if (filters.startDate && filters.endDate) {
    whereClause += " WHERE `created_at` >= ? AND `created_at` <= ?";
    params.push(filters.startDate, filters.endDate);
  } else if (filters.startDate) {
    whereClause += " WHERE `created_at` >= ?";
    params.push(filters.startDate);
  } else if (filters.endDate) {
    whereClause += " WHERE `created_at` <= ?";
    params.push(filters.endDate);
  }

  const addFilter = (column, value, alias) => {
    if (value !== undefined && value !== null) {
      whereClause += (whereClause ? " AND " : "WHERE ") + "`" + (alias || column) + "` = ?";
      params.push(value);
    }
  };

  addFilter("region_id", filters.regionId);
  addFilter("agent_id", filters.agentId);
  addFilter("status", filters.status);
  addFilter("sale_status", filters.saleStatus);

  return { whereClause, params };
}

async function mysqlQuery(sql, params = []) {
  const [rows] = await pool.query(sql, params);
  return rows;
}

async function verifyPassword(password, hash) {
  if (!hash) return false;
  if (hash.startsWith("$2")) {
    return bcrypt.compare(password, hash);
  }
  if (hash.includes(":")) {
    const [salt, expectedHash] = hash.split(":");
    const derivedKey = pbkdf2Sync(password, Buffer.from(salt, "hex"), 10000, 64, "sha256");
    return createHmac("sha256", Buffer.from(salt, "hex")).update(derivedKey).digest("hex") === expectedHash ||
           derivedKey.toString("hex") === expectedHash;
  }
  return false;
}

async function hashPassword(password) {
  return bcrypt.hash(password, 10);
}

// ===== AUTH ENDPOINTS =====
app.post("/api/auth/register", async (req, res) => {
  try {
    const { email, password, full_name, phone, role = 5, region } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: "Email and password required" });
    }
    const [existing] = await pool.query("SELECT id FROM users WHERE email = ?", [email]);
    if (existing.length > 0) {
      return res.status(409).json({ error: "Email already registered" });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      `INSERT INTO users (id, email, full_name, phone, role, region, password_hash, created_at, updated_at)
       VALUES (UUID(), ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [email, full_name, phone, role, region, hashedPassword]
    );
    const insertedId = result.insertId || (result[0] && result[0].insertId);
    const [user] = await pool.query("SELECT id, email, full_name, phone, role, region, created_at FROM users WHERE id = ?", [result.insertId || result[2] || null]);
    // Better approach: fetch by email since UUID generated
    const [userByEmail] = await pool.query("SELECT id, email, full_name, phone, role, region, created_at FROM users WHERE email = ?", [email]);
    const token = jwt.sign({ id: userByEmail[0].id, email: userByEmail[0].email, role: userByEmail[0].role }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
    res.status(201).json({ user: userByEmail[0], token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: "Email and password required" });
    }
    const [users] = await pool.query("SELECT * FROM users WHERE email = ?", [email]);
    if (users.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }
    const user = users[0];
    const validPassword = await verifyPassword(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: "Invalid credentials" });
    }
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
    const { password_hash, ...userWithoutPassword } = user;
    res.json({ user: userWithoutPassword, token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/auth/me", verifyToken, async (req, res) => {
  try {
    const [users] = await pool.query("SELECT id, email, full_name, phone, role, region, created_at FROM users WHERE id = ?", [req.user.id]);
    if (users.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }
    res.json(users[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/admin/team-members", verifyToken, requireRole(1, 2, 3), async (req, res) => {
  try {
    const { email, password, full_name, phone, role, region_id, region, sub_region } = req.body;
    const creatorRole = Number(req.user.role);
    const requestedRole = Number(role);
    const allowedRoles = creatorRole === 1 ? [2, 3, 4, 5]
      : creatorRole === 2 ? [4, 5] : [5];
    if (!email || !password || !full_name || !allowedRoles.includes(requestedRole)) {
      return res.status(400).json({ error: "Invalid team member details or role" });
    }
    const [existing] = await pool.query("SELECT id FROM users WHERE email = ?", [email]);
    if (existing.length) return res.status(409).json({ error: "Email already registered" });

    const id = randomUUID();
    const passwordHash = await bcrypt.hash(password, 10);
    await pool.query(
      `INSERT INTO users (id, email, password_hash, full_name, phone, role, region_id, region, sub_region, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [id, email, passwordHash, full_name, phone || null, requestedRole,
        region_id || null, region || null, sub_region || null]
    );
    const [users] = await pool.query(
      "SELECT id, email, full_name, phone, role, region_id, region, sub_region, created_at FROM users WHERE id = ?",
      [id]
    );
    res.status(201).json(users[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/auth/refresh", verifyToken, async (req, res) => {
  try {
    const [users] = await pool.query("SELECT id, email, role FROM users WHERE id = ?", [req.user.id]);
    if (users.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }
    const token = jwt.sign({ id: users[0].id, email: users[0].email, role: users[0].role }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
    res.json({ token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Password reset request - generates a reset token
app.post("/api/auth/forgot-password", async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: "Email is required" });
    }
    const crypto = require("crypto");
    const resetToken = crypto.randomBytes(32).toString("hex");
    const tokenExpiry = new Date(Date.now() + 3600000); // 1 hour

    const [result] = await pool.query(
      "UPDATE users SET reset_token = ?, reset_token_expiry = ? WHERE email = ?",
      [resetToken, tokenExpiry, email]
    );

    if (result.affectedRows === 0) {
      // Don't reveal whether user exists
      return res.json({ message: "If an account exists for this email, a reset link has been sent." });
    }

    // In production, send email with resetToken
    // For now, return the token for client-side testing
    res.json({
      message: "If an account exists for this email, a password reset link has been sent.",
      resetToken: resetToken,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Password reset - uses token to set new password
app.post("/api/auth/reset-password", async (req, res) => {
  try {
    const { token, password } = req.body;
    if (!token || !password) {
      return res.status(400).json({ error: "Token and password are required" });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: "Password must be at least 6 characters" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      "UPDATE users SET password_hash = ?, reset_token = NULL, reset_token_expiry = NULL WHERE reset_token = ? AND reset_token_expiry > NOW()",
      [hashedPassword, token]
    );

    if (result.affectedRows === 0) {
      return res.status(401).json({ error: "Invalid or expired token" });
    }

    res.json({ message: "Password updated successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ===== GENERIC CRUD FACTORY WITH AUTH =====
const createRouter = (tableName, options = {}) => {
  const router = express.Router();
  const { requireAuth = true, allowRoles, customQueries } = options;

  if (requireAuth) {
    router.use(verifyToken);
  }
  if (allowRoles) {
    router.use(requireRole(...allowRoles));
  }

  router.get("/", async (req, res) => {
    try {
      const limit = Math.min(parseInt(req.query.limit) || 100, 500);
      const offset = parseInt(req.query.offset) || 0;
      const { cols: tableCols } = await getTableColumns(tableName);
      let requestedOrderBy = req.query.orderBy || "created_at";
      if (!tableCols.has(requestedOrderBy)) {
        requestedOrderBy = tableCols.has('updated_at') ? 'updated_at' : Array.from(tableCols)[0] || 'id';
      }
      if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(requestedOrderBy)) {
        throw new Error("Invalid order column");
      }
      const orderBy = requestedOrderBy;
      const orderDir = String(req.query.orderDir || "desc").toLowerCase() === "asc" ? "ASC" : "DESC";

      let whereClause = "";
      const params = [];
      if (req.query.filter) {
        const filters = JSON.parse(req.query.filter);
        Object.entries(filters).forEach(([key, value]) => {
          // Filter columns are validated against a conservative identifier
          // pattern before interpolation; values remain parameterized.
          if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(key)) {
            throw new Error(`Invalid filter column: ${key}`);
          }
          const condition = value && typeof value === "object" && !Array.isArray(value)
            ? value
            : { eq: value };
          const operators = { eq: "=", neq: "<>", gt: ">", gte: ">=", lt: "<", lte: "<=", is: "IS" };
          const entries = Object.entries(condition);
          if (entries.length === 0) throw new Error(`Invalid filter for ${key}`);
          for (const [operator, operand] of entries) {
          if (operator === "in") {
            if (!Array.isArray(operand) || operand.length === 0) {
              whereClause += (whereClause ? " AND " : "WHERE ") + "1 = 0";
            } else {
              whereClause += (whereClause ? " AND " : "WHERE ") + `\`${key}\` IN (${operand.map(() => "?").join(",")})`;
              params.push(...operand);
            }
          } else {
            if (operator === "is" && operand === null) {
              whereClause += (whereClause ? " AND " : "WHERE ") + `\`${key}\` IS NULL`;
              return;
            }
            if (operator === "neq" && operand === null) {
              whereClause += (whereClause ? " AND " : "WHERE ") + `\`${key}\` IS NOT NULL`;
              return;
            }
            const sqlOperator = operators[operator];
            if (!sqlOperator) throw new Error(`Unsupported filter operator: ${operator}`);
            whereClause += (whereClause ? " AND " : "WHERE ") + `\`${key}\` ${sqlOperator} ?`;
            params.push(operand);
          }
          }
        });
      }

      params.push(limit, offset);
      const [rows] = await pool.query(
        `SELECT * FROM \`${tableName}\` ${whereClause} ORDER BY \`${orderBy}\` ${orderDir} LIMIT ? OFFSET ?`,
        params
      );
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.get("/:id", async (req, res) => {
    try {
      const [rows] = await pool.query(
        `SELECT * FROM \`${tableName}\` WHERE id = ?`,
        [req.params.id],
      );
      if (rows.length === 0)
        return res.status(404).json({ error: "Not found" });
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  const cache = {};
  async function getTableColumns(t) {
    if (cache[t]) return cache[t];
    const [rows] = await pool.query(`SHOW COLUMNS FROM \`${t}\``);
    const cols = new Set(rows.map(r => r.Field));
    const types = {};
    for (const r of rows) {
      types[r.Field] = r.Type.toLowerCase();
    }
    cache[t] = { cols, types };
    return cache[t];
  }

  function toMysqlDateTime(value) {
    if (value == null) return value;
    if (typeof value === 'string') {
      const d = new Date(value);
      if (!isNaN(d.getTime())) {
        return d.toISOString().slice(0, 19).replace('T', ' ');
      }
    }
    if (value instanceof Date) {
      return value.toISOString().slice(0, 19).replace('T', ' ');
    }
    return value;
  }

  async function prepareData(reqBody, cols, types) {
    const data = {};
    for (const [k, v] of Object.entries(reqBody)) {
      if (k === 'id' || k === 'isSynced' || k === 'created_at' || k === 'updated_at') continue;
      if (cols.has(k)) {
        const t = types[k] || '';
        if (t.includes('datetime') || t.includes('timestamp') || t.includes('date')) {
          data[k] = toMysqlDateTime(v);
        } else {
          data[k] = v;
        }
      }
    }
    return data;
  }

  router.post("/", async (req, res) => {
    try {
      const { cols, types } = await getTableColumns(tableName);
      const now = new Date();
      const nowStr = now.toISOString().slice(0, 19).replace('T', ' ');
      const data = await prepareData(req.body, cols, types);
      if (cols.has('id')) data.id = req.body.id || randomUUID();
      if (cols.has('isSynced')) data.isSynced = req.body.isSynced !== undefined ? req.body.isSynced : 1;
      if (cols.has('created_at')) data.created_at = toMysqlDateTime(req.body.created_at) || nowStr;
      if (cols.has('updated_at')) data.updated_at = toMysqlDateTime(req.body.updated_at) || nowStr;
      const [result] = await pool.query(`INSERT INTO \`${tableName}\` SET ?`, [data]);
      const [rows] = await pool.query(
        `SELECT * FROM \`${tableName}\` WHERE id = ?`,
        [data.id || result.insertId],
      );
      res.status(201).json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.put("/:id", async (req, res) => {
    try {
      const { cols, types } = await getTableColumns(tableName);
      const now = new Date();
      const nowStr = now.toISOString().slice(0, 19).replace('T', ' ');
      const data = await prepareData(req.body, cols, types);
      if (cols.has('updated_at')) data.updated_at = nowStr;
      await pool.query(`UPDATE \`${tableName}\` SET ? WHERE id = ?`, [data, req.params.id]);
      const [rows] = await pool.query(
        `SELECT * FROM \`${tableName}\` WHERE id = ?`,
        [req.params.id],
      );
      if (rows.length === 0) return res.status(404).json({ error: "Not found" });
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.patch("/:id", async (req, res) => {
    try {
      const { cols, types } = await getTableColumns(tableName);
      const now = new Date();
      const nowStr = now.toISOString().slice(0, 19).replace('T', ' ');
      const data = await prepareData(req.body, cols, types);
      if (cols.has('updated_at')) data.updated_at = nowStr;
      await pool.query(`UPDATE \`${tableName}\` SET ? WHERE id = ?`, [data, req.params.id]);
      const [rows] = await pool.query(
        `SELECT * FROM \`${tableName}\` WHERE id = ?`,
        [req.params.id],
      );
      if (rows.length === 0) return res.status(404).json({ error: "Not found" });
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.delete("/:id", async (req, res) => {
    try {
      await pool.query(`DELETE FROM \`${tableName}\` WHERE id = ?`, [req.params.id]);
      res.json({ message: "Deleted successfully" });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  if (customQueries) {
    customQueries(router);
  }

  return router;
};

// Health check
app.get("/api/admin/dashboard", verifyToken, requireRole(1), async (req, res) => {
  try {
    const [counts] = await Promise.all([
      pool.query(`SELECT
        (SELECT COUNT(*) FROM users) AS users,
        (SELECT COUNT(*) FROM schools) AS schools,
        (SELECT COUNT(*) FROM tasks) AS tasks,
        (SELECT COUNT(*) FROM orders) AS orders,
        (SELECT COUNT(*) FROM school_visits) AS visits,
        (SELECT COUNT(*) FROM catalog_items) AS catalog_items`),
    ]);
    const [[profile]] = await pool.query("SELECT full_name, role, region, email FROM users WHERE id = ?", [req.user.id]);
    const [recentOrders] = await pool.query("SELECT order_number, school_name, status, checkout_amount FROM orders ORDER BY created_at DESC LIMIT 5");
    res.json({ counts: counts[0][0], currentUserProfile: profile || null, recentOrders });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    database: "mysql",
    timestamp: new Date().toISOString(),
  });
});

// Report data fetchers using direct MySQL queries
const REPORT_QUERIES = {
  sales_summary: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const schools = await mysqlQuery(`SELECT * FROM \`schools\` ${whereClause} ORDER BY \`created_at\` DESC`, params);
    const users = await mysqlQuery(`SELECT * FROM \`users\``);
    const orders = await mysqlQuery(`SELECT * FROM \`orders\` ${whereClause} ORDER BY \`created_at\` DESC`, [...params]);
    const schoolSales = await mysqlQuery(`SELECT * FROM \`school_sales\` ${whereClause}`, params);
    const orderItems = await mysqlQuery(`SELECT * FROM \`order_items\``);

    const orderStats = {};
    orders?.forEach((order) => {
      orderStats[order.status] = (orderStats[order.status] || 0) + 1;
    });

    const pipelineSummary = {};
    schoolSales?.forEach((sale) => {
      pipelineSummary[sale.sale_status] = pipelineSummary[sale.sale_status] || {
        count: 0,
        total_value: 0,
      };
      pipelineSummary[sale.sale_status].count += 1;
      pipelineSummary[sale.sale_status].total_value += parseFloat(
        sale.expected_value || 0,
      );
    });

    const revenueWon =
      schoolSales
        ?.filter((s) => s.sale_status === "won")
        .reduce((sum, s) => sum + parseFloat(s.expected_value || 0), 0) || 0;

    const productMap = {};
    orderItems?.forEach((item) => {
      if (!productMap[item.product_name]) {
        productMap[item.product_name] = { total_qty: 0, total_value: 0 };
      }
      productMap[item.product_name].total_qty += item.quantity || 0;
      productMap[item.product_name].total_value += parseFloat(
        item.line_total || 0,
      );
    });
    const topProducts = Object.entries(productMap)
      .map(([name, stats]) => ({ product_name: name, ...stats }))
      .sort((a, b) => b.total_value - a.total_value)
      .slice(0, 10);

    return {
      total_schools: schools?.length || 0,
      total_users: users?.length || 0,
      total_orders: orders?.length || 0,
      order_status_breakdown: orderStats,
      pipeline_summary: pipelineSummary,
      won_revenue: revenueWon,
      top_products: topProducts,
    };
  },

  pipeline_analysis: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const schoolSales = await mysqlQuery(`SELECT * FROM \`school_sales\` ${whereClause}`, params);
    const users = await mysqlQuery(`SELECT id, full_name, role FROM \`users\``);
    const schools = await mysqlQuery(`SELECT id, name FROM \`schools\``);

    const userMap = Object.fromEntries((users || []).map((u) => [u.id, u]));
    const schoolMap = Object.fromEntries((schools || []).map((s) => [s.id, s]));

    const byStage = {};
    (schoolSales || []).forEach((sale) => {
      if (!byStage[sale.sale_status]) {
        byStage[sale.sale_status] = {
          count: 0,
          total_value: 0,
          total_probability: 0,
          weighted_forecast: 0,
        };
      }
      byStage[sale.sale_status].count += 1;
      byStage[sale.sale_status].total_value += parseFloat(
        sale.expected_value || 0,
      );
      byStage[sale.sale_status].total_probability += sale.probability || 0;
      byStage[sale.sale_status].weighted_forecast += parseFloat(
        sale.weighted_forecast || 0,
      );
    });

    const byAgent = {};
    (schoolSales || []).forEach((sale) => {
      const agentId = sale.agent_id;
      if (!byAgent[agentId]) {
        byAgent[agentId] = {
          full_name: userMap[agentId]?.full_name || "Unknown",
          role: userMap[agentId]?.role,
          opportunities: 0,
          total_value: 0,
          weighted_forecast: 0,
        };
      }
      byAgent[agentId].opportunities += 1;
      byAgent[agentId].total_value += parseFloat(sale.expected_value || 0);
      byAgent[agentId].weighted_forecast += parseFloat(
        sale.weighted_forecast || 0,
      );
    });

    const staleOpps =
      (schoolSales || [])
        .filter(
          (s) =>
            !["won", "lost", "dormant"].includes(s.sale_status) &&
            ((s.next_action_date &&
              new Date(s.next_action_date) < new Date()) ||
              (s.stage_sla_due_at &&
                new Date(s.stage_sla_due_at) < new Date())),
        )
        .slice(0, 50)
        .map((s) => ({
          id: s.id,
          agent_name: userMap[s.agent_id]?.full_name || "Unknown",
          school_name: schoolMap[s.school_id]?.name || "Unknown",
          sale_status: s.sale_status,
          next_action: s.next_action,
          next_action_date: s.next_action_date,
          stage_sla_due_at: s.stage_sla_due_at,
          risk_level: s.risk_level,
        })) || [];

    return {
      by_stage: Object.entries(byStage).map(([stage, data]) => ({
        sale_status: stage,
        ...data,
      })),
      by_agent: Object.entries(byAgent)
        .map(([agent_id, data]) => ({ agent_id, ...data }))
        .sort((a, b) => b.total_value - a.total_value),
      stale_opportunities: staleOpps,
    };
  },

  agent_performance: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const users = await mysqlQuery(`SELECT id, full_name, role, region FROM \`users\``);
    const tasks = await mysqlQuery(`SELECT * FROM \`tasks\` ${whereClause} ORDER BY \`created_at\` DESC`, [...params]);
    const routePlans = await mysqlQuery(`SELECT * FROM \`route_plans\` ${whereClause}`, [...params]);
    const visits = await mysqlQuery(`SELECT * FROM \`school_visits\` ${whereClause}`, [...params]);
    const schools = await mysqlQuery(`SELECT id, name FROM \`schools\``);

    const schoolMap = Object.fromEntries((schools || []).map((s) => [s.id, s]));

    const agents =
      (users || [])
        .filter((u) => u.role === 4 || u.role === 5)
        .map((u) => {
          const userTasks = (tasks || []).filter((t) => t.assigned_to === u.id) || [];
          const userRoutes =
            (routePlans || []).filter((r) => r.assigned_to === u.id) || [];
          const userVisits = (visits || []).filter((v) => v.agent_id === u.id) || [];
          return {
            id: u.id,
            full_name: u.full_name,
            role: u.role,
            region: u.region,
            total_tasks: userTasks.length,
            completed_tasks: userTasks.filter((t) => t.status === "closed")
              .length,
            total_routes: userRoutes.length,
            completed_routes: userRoutes.filter((r) => r.status === "completed")
              .length,
            total_visits: userVisits.length,
          };
        }) || [];

    const visitCounts = {};
    (visits || []).forEach((v) => {
      const key = `${v.agent_id}-${v.school_id}`;
      visitCounts[key] = (visitCounts[key] || 0) + 1;
    });
    const topSchools = Object.entries(visitCounts)
      .map(([key, count]) => {
        const [agentId, schoolId] = key.split("-");
        return {
          agent_name:
            (users || []).find((u) => u.id === agentId)?.full_name || "Unknown",
          school_name: schoolMap[schoolId]?.name || "Unknown",
          visits: count,
        };
      })
      .sort((a, b) => b.visits - a.visits)
      .slice(0, 20);

    return { agents, most_visited_schools: topSchools };
  },

  regional_summary: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const regions = await mysqlQuery(`SELECT * FROM \`regions\``);
    const users = await mysqlQuery(`SELECT id, full_name, role, region_id, region FROM \`users\``);
    const schools = await mysqlQuery(`SELECT id, name, region_id, region FROM \`schools\` ${whereClause}`, params);
    const sales = await mysqlQuery(`SELECT * FROM \`school_sales\` ${whereClause}`, [...params]);

    const byRegion =
      (regions || []).map((r) => {
        const regionUsers = (users || []).filter((u) => u.region_id === r.id || u.region === r.region) || [];
        const regionSchools =
          (schools || []).filter((s) => s.region_id === r.id || s.region === r.region) || [];
        const regionSales =
          (sales || []).filter((s) => s.region_id === r.id || s.region === r.region) || [];
        const pipelineValue = regionSales.reduce(
          (sum, s) => sum + parseFloat(s.expected_value || 0),
          0,
        );
        const wonValue = regionSales
          .filter((s) => s.sale_status === "won")
          .reduce((sum, s) => sum + parseFloat(s.expected_value || 0), 0);
        return {
          region: r.region,
          sub_region: r.sub_region,
          user_count: regionUsers.length,
          school_count: regionSchools.length,
          opportunity_count: regionSales.length,
          pipeline_value: pipelineValue,
          won_value: wonValue,
        };
      }) || [];

    return { by_region: byRegion };
  },

  event_summary: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const events = await mysqlQuery(`SELECT * FROM \`events\` ${whereClause} ORDER BY \`start_at\` DESC`, params);
    const assignments = await mysqlQuery(`SELECT * FROM \`event_assignments\``);
    const checkins = await mysqlQuery(`SELECT * FROM \`event_checkins\` ${whereClause}`, [...params]);
    const leads = await mysqlQuery(`SELECT * FROM \`event_leads\` ${whereClause}`, [...params]);
    const samples = await mysqlQuery(`SELECT * FROM \`event_samples\` ${whereClause}`, [...params]);
    const expenses = await mysqlQuery(`SELECT * FROM \`event_expenses\` ${whereClause}`, [...params]);

    const eventSummaries =
      (events || []).map((e) => {
        const eventAssignments =
          (assignments || []).filter((a) => a.event_id === e.id) || [];
        const eventCheckins =
          (checkins || []).filter((c) => c.event_id === e.id) || [];
        const eventLeads = (leads || []).filter((l) => l.event_id === e.id) || [];
        const eventSamples = samples?.filter((s) => s.event_id === e.id) || [];
        const eventExpenses =
          (expenses || []).filter((ex) => ex.event_id === e.id) || [];
        return {
          id: e.id,
          name: e.name,
          event_type: e.event_type,
          region: e.region,
          start_at: e.start_at,
          end_at: e.end_at,
          expected_attendance: e.expected_attendance,
          budget: e.budget,
          status: e.status,
          assigned_agents: new Set(eventAssignments.map((a) => a.agent_id))
            .size,
          checkins: eventCheckins.length,
          leads: eventLeads.length,
          samples: eventSamples.length,
          total_expenses: eventExpenses.reduce(
            (sum, ex) => sum + parseFloat(ex.amount || 0),
            0,
          ),
        };
      }) || [];

    return { events: eventSummaries };
  },

  sample_roi: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const users = await mysqlQuery(`SELECT id, full_name, role FROM \`users\``);
    const distributions = await mysqlQuery(`SELECT * FROM \`school_sample_distributions\` ${whereClause}`, params);
    const orders = await mysqlQuery(`SELECT * FROM \`orders\` ${whereClause}`, [...params]);
    const sales = await mysqlQuery(`SELECT * FROM \`school_sales\` ${whereClause}`, [...params]);

    const roi =
      (users || [])
        .filter((u) => u.role === 4 || u.role === 5)
        .map((u) => {
          const userDists =
            (distributions || []).filter((d) => d.agent_id === u.id) || [];
          const userOrders = (orders || []).filter((o) => o.agent_id === u.id) || [];
          const userSales = (sales || []).filter((s) => s.agent_id === u.id) || [];
          const schoolsReached = new Set(userDists.map((d) => d.school_id))
            .size;
          const revenueEarned = userOrders
            .filter((o) => ["approved", "paid", "completed"].includes(o.status))
            .reduce((sum, o) => sum + parseFloat(o.checkout_amount || 0), 0);
          const wonValue = userSales
            .filter((s) => s.sale_status === "won")
            .reduce((sum, s) => sum + parseFloat(s.expected_value || 0), 0);
          return {
            full_name: u.full_name,
            role: u.role,
            samples_given: userDists.length,
            schools_reached: schoolsReached,
            revenue_earned: revenueEarned,
            won_value: wonValue,
          };
        }) || [];

    return { roi };
  },

  targets_analysis: async (filters = {}) => {
    const { whereClause, params } = buildWhereClause(filters);

    const targets = await mysqlQuery(`SELECT * FROM \`targets\` ${whereClause}`, params);
    const regions = await mysqlQuery(`SELECT id, region, sub_region FROM \`regions\``);
    const users = await mysqlQuery(`SELECT id, full_name FROM \`users\``);

    const regionMap = Object.fromEntries((regions || []).map((r) => [r.id, r]));
    const userMap = Object.fromEntries((users || []).map((u) => [u.id, u]));

    const formatted =
      (targets || []).map((t) => ({
        scope: t.scope,
        target_type: t.target_type,
        target_period: t.target_period,
        region: regionMap[t.region_id]?.region,
        sub_region: regionMap[t.region_id]?.sub_region,
        assigned_to_name: userMap[t.assigned_to]?.full_name,
        target_data: t.target_data,
      })) || [];

    return { targets: formatted };
  },
};

// Report generation endpoint
app.post("/api/ai/report", async (req, res) => {
  try {
    const { report_type, filters = {}, prompt } = req.body;
    const openRouterKey = process.env.OPENROUTER_API_KEY;

    if (!openRouterKey) {
      return res
        .status(500)
        .json({ error: "OpenRouter API key not configured on server" });
    }

    const fetcher = REPORT_QUERIES[report_type];
    if (!fetcher) {
      return res
        .status(400)
        .json({
          error: `Unsupported report type: ${report_type}. Supported: ${Object.keys(REPORT_QUERIES).join(", ")}`,
        });
    }

    let data;
    try {
      data = await fetcher(filters);
    } catch (dbError) {
      console.error("Report data fetch error:", dbError);
      return res
        .status(500)
        .json({ error: `Failed to fetch report data: ${dbError.message}` });
    }

    const reportContext = JSON.stringify(data, null, 2);
    const systemPrompt = `${DB_SCHEMA_PROMPT}

You are generating a comprehensive report from live DeHeus sales data below.
Analyze the data thoroughly, highlight key insights, trends, anomalies, and actionable recommendations.
Structure the report with clear sections, bullet points, and numbers. Be specific and data-driven.

Live Data:
${reportContext}`;

    const userPrompt =
      prompt || "Generate a comprehensive report from the provided data.";

    const response = await fetch(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openRouterKey}`,
          "HTTP-Referer":
            process.env.OPENROUTER_HTTP_REFERER || "https://deheus.app",
          "X-OpenRouter-Title":
            process.env.OPENROUTER_APP_TITLE || "DeHeus Sales App",
        },
        body: JSON.stringify({
          model: process.env.OPENROUTER_MODEL || "openai/gpt-4o-mini",
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
        }),
      },
    );

    const result = await response.json();
    if (!response.ok) {
      return res.status(response.status).json(result);
    }

    res.json({
      report_type,
      generated_at: new Date().toISOString(),
      report: result.choices[0]?.message?.content || "No report generated.",
    });
  } catch (error) {
    console.error("Report generation error:", error);
    res.status(500).json({ error: error.message });
  }
});

// AI Chat proxy - forwards requests to OpenRouter API
app.post("/api/ai/chat", async (req, res) => {
  try {
    let { messages, context } = req.body;
    const openRouterKey = process.env.OPENROUTER_API_KEY;

    if (!openRouterKey) {
      return res
        .status(500)
        .json({ error: "OpenRouter API key not configured on server" });
    }

    if (!context) {
      try {
        const [sales, pipeline, agents] = await Promise.all([
          REPORT_QUERIES.sales_summary({}),
          REPORT_QUERIES.pipeline_analysis({}),
          REPORT_QUERIES.agent_performance({})
        ]);
        context = JSON.stringify({ sales, pipeline, agents });
      } catch (err) {
        console.error("Auto context fetch failed:", err);
      }
    }

    const systemPrompt = context
      ? `${DB_SCHEMA_PROMPT}\n\nYou are analyzing the following performance data. Answer questions about it accurately using your schema knowledge.\n\nPerformance Context:\n${context}`
      : `${DB_SCHEMA_PROMPT}\n\nYou are a helpful AI assistant. You don't have access to live data right now, so please explain that to the user instead of listing the database schema.`;

    const response = await fetch(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openRouterKey}`,
          "HTTP-Referer":
            process.env.OPENROUTER_HTTP_REFERER || "https://deheus.app",
          "X-OpenRouter-Title":
            process.env.OPENROUTER_APP_TITLE || "DeHeus Sales App",
        },
        body: JSON.stringify({
          model: process.env.OPENROUTER_MODEL || "openai/gpt-4o-mini",
          messages: [{ role: "system", content: systemPrompt }, ...messages],
        }),
      },
    );

    const data = await response.json();
    if (!response.ok) {
      return res.status(response.status).json(data);
    }
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Data helper endpoint - returns raw data for AI consumption or direct use
app.get("/api/reports/role5-performance", verifyToken, async (req, res) => {
  try {
    const start = new Date(req.query.start);
    const end = new Date(req.query.end);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      return res.status(400).json({ error: "Valid start and end dates are required" });
    }
    const [rows] = await pool.query(`
      SELECT u.id AS user_id, u.full_name, u.region,
        COALESCE(t.total_tasks, 0) AS total_tasks,
        COALESCE(t.completed_tasks, 0) AS completed_tasks,
        COALESCE(r.total_routes, 0) AS total_routes,
        COALESCE(r.completed_routes, 0) AS completed_routes,
        COALESCE(v.total_visits, 0) AS total_visits
      FROM users u
      LEFT JOIN (
        SELECT assigned_to, COUNT(*) AS total_tasks,
          SUM(status = 'closed') AS completed_tasks
        FROM tasks WHERE created_at >= ? AND created_at <= ? GROUP BY assigned_to
      ) t ON t.assigned_to = u.id
      LEFT JOIN (
        SELECT assigned_to, COUNT(*) AS total_routes,
          SUM(status = 'completed') AS completed_routes
        FROM route_plans WHERE created_at >= ? AND created_at <= ? GROUP BY assigned_to
      ) r ON r.assigned_to = u.id
      LEFT JOIN (
        SELECT agent_id, COUNT(*) AS total_visits
        FROM school_visits WHERE visited_at >= ? AND visited_at <= ? GROUP BY agent_id
      ) v ON v.agent_id = u.id
      WHERE u.role = 5`, [start, end, start, end, start, end]);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/orders/school-sale-checkout", verifyToken, async (req, res) => {
  let connection;
  try {
    const { order, items, sale } = req.body || {};
    if (!order || !order.id || !Array.isArray(items) || !sale) {
      return res.status(400).json({ error: "order.id, items, and sale are required" });
    }
    connection = await pool.getConnection();
    await connection.beginTransaction();
    await connection.query("CALL sp_create_school_sale_checkout(?, ?, ?)", [
      JSON.stringify(order), JSON.stringify(items), JSON.stringify(sale),
    ]);
    const orderId = order.id;
    const [orders] = await connection.query("SELECT * FROM orders WHERE id = ?", [orderId]);
    if (!orders.length) throw new Error("Checkout did not create an order");
    await connection.commit();
    res.json({ order: orders[0] });
  } catch (error) {
    if (connection) await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    if (connection) connection.release();
  }
});

app.get("/api/ai/data/:table", async (req, res) => {
  try {
    const { table } = req.params;
    const allowedTables = [
      "users", "schools", "tasks", "geofences", "route_plans", "regions", "region_assignments",
      "catalog_items", "orders", "order_items", "school_sales", "school_visits", "school_follow_ups", "school_sample_distributions",
      "messages", "events", "event_assignments", "event_checkins", "event_leads", "event_samples", "event_expenses",
      "targets", "opportunity_activities", "pipeline_history",
      "supervisor_alerts", "supervisor_incidents", "supervisor_notes", "supervisor_notifications", "audit_events", "geofence_events",
      "task_completion_evidence", "debt_collections", "visitations", "consignments", "consignment_items",
    ];

    if (!allowedTables.includes(table)) {
      return res.status(400).json({ error: `Table not allowed: ${table}` });
    }

    const limit = Math.min(parseInt(req.query.limit || "100", 10), 500);
    const offset = parseInt(req.query.offset || "0", 10);

    const [rows] = await pool.query(`SELECT * FROM \`${table}\` LIMIT ? OFFSET ?`, [
      limit,
      offset,
    ]);
    res.json({ table, count: rows.length, data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/reports/potential-duplicates", verifyToken, async (_req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT s1.id, s1.name, s1.phone,
             s2.id AS duplicate_id, s2.name AS duplicate_name,
             CASE
               WHEN s1.phone = s2.phone THEN 'Matching Phone Number'
               ELSE 'Matching Name'
             END AS reason
      FROM schools s1
      JOIN schools s2 ON s1.id < s2.id
      WHERE s1.phone = s2.phone
         OR LOWER(s1.name) = LOWER(s2.name)
      ORDER BY s1.name, s2.name
      LIMIT 1000
    `);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Register routes for all tables
const tables = [
  // Core tables
  "users", "schools", "tasks", "geofences", "route_plans", "regions", "region_assignments",
  // Catalog & Inventory
  "catalog_items",
  // Orders & Sales
  "orders", "order_items", "school_sales", "school_visits", "school_follow_ups", "school_sample_distributions",
  // Communications
  "messages",
  "visit_checkins", "sample_requests",
  // Events
  "events", "event_assignments", "event_checkins", "event_tasks", "event_leads", "event_orders", "event_sales", "event_samples", "event_photos", "event_expenses", "event_reports",
  // Targets & Performance
  "targets", "opportunity_activities", "pipeline_history",
  "project_forms", "project_form_responses",
  "social_conversations", "social_messages",
  // Supervision & Monitoring
  "supervisor_alerts", "supervisor_incidents", "supervisor_notes", "supervisor_notifications", "audit_events", "geofence_events",
  // Task Evidence
  "task_completion_evidence",
  // Debt Collections
  "debt_collections",
  // Visitations (route plan checklist)
  "visitations",
  // Consignments
  "consignments", "consignment_items",
];

tables.forEach((table) => {
  app.use(`/api/${table}`, createRouter(table));
});

// Root path
app.get("/", (req, res) => {
  res.json({
    message: "Welcome to DeHeus MySQL API",
    endpoints: tables.map((t) => `/api/${t}`),
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Server is running on port ${port}`);
});

const uploadRouter = express.Router();
uploadRouter.use("/upload", express.raw({ type: "*/*" }));

uploadRouter.post("/upload/:bucket/:path(*)", verifyToken, (req, res) => {
  try {
    if (!req.body || req.body.length === 0) {
      return res.status(400).json({ error: "No file data provided" });
    }
    const bucket = req.params.bucket;
    const filePath = req.params.path;
    const dir = path.join(UPLOAD_DIR, bucket, path.dirname(filePath));
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    const fullPath = path.join(UPLOAD_DIR, bucket, filePath);
    fs.writeFile(fullPath, req.body, (err) => {
      if (err) {
        console.error("Upload error:", err);
        return res.status(500).json({ error: "Failed to write file" });
      }
      const publicUrl = `/uploads/${bucket}/${filePath}`;
      res.json({ url: publicUrl, path: path.join(bucket, filePath) });
    });
  } catch (e) {
    console.error("Upload error:", e);
    res.status(500).json({ error: "Upload failed" });
  }
});

app.use("/api", uploadRouter);
app.use("/uploads", express.static(UPLOAD_DIR));
