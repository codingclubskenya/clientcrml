const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
require("dotenv").config();
const { DB_SCHEMA_PROMPT } = require("./schema_context");

const app = express();
const port = process.env.PORT || 3000;

const dbHost = process.env.DB_HOST || process.env.MYSQL_HOST || "localhost";
const dbUser = process.env.DB_USER || process.env.MYSQL_USER || "root";
const dbPassword = process.env.DB_PASSWORD || process.env.MYSQL_PASSWORD || "";
const dbName = process.env.DB_NAME || process.env.MYSQL_DATABASE || "";

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

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

async function supabaseRestQuery(table, options = {}) {
  const url = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
  if (options.select) url.searchParams.set("select", options.select);
  if (options.limit) url.searchParams.set("limit", String(options.limit));
  if (options.offset) url.searchParams.set("offset", String(options.offset));
  if (options.order) url.searchParams.set("order", options.order);
  if (options.filter) {
    for (const [key, value] of Object.entries(options.filter)) {
      url.searchParams.set(key, value);
    }
  }

  const response = await fetch(url.toString(), {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Supabase query failed: ${response.status} ${text}`);
  }

  return response.json();
}

function buildSupabaseFilter(filters) {
  const filter = {};
  if (!filters || typeof filters !== "object") return filter;

  if (filters.startDate && filters.endDate) {
    filter.created_at = `gte.${filters.startDate},lte.${filters.endDate}`;
  } else if (filters.startDate) {
    filter.created_at = `gte.${filters.startDate}`;
  } else if (filters.endDate) {
    filter.created_at = `lte.${filters.endDate}`;
  }

  if (filters.regionId) {
    filter.region_id = `eq.${filters.regionId}`;
  }
  if (filters.agentId) {
    filter.agent_id = `eq.${filters.agentId}`;
  }
  if (filters.status) {
    filter.status = `eq.${filters.status}`;
  }
  if (filters.saleStatus) {
    filter.sale_status = `eq.${filters.saleStatus}`;
  }
  return filter;
}

app.use(cors());
app.use(express.json());

// Generic CRUD factory for MySQL
const createRouter = (tableName) => {
  const router = express.Router();

  router.get("/", async (req, res) => {
    try {
      const [rows] = await pool.query(`SELECT * FROM ${tableName}`);
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.get("/:id", async (req, res) => {
    try {
      const [rows] = await pool.query(
        `SELECT * FROM ${tableName} WHERE id = ?`,
        [req.params.id],
      );
      if (rows.length === 0)
        return res.status(404).json({ error: "Not found" });
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.post("/", async (req, res) => {
    try {
      const [result] = await pool.query(`INSERT INTO ${tableName} SET ?`, [
        req.body,
      ]);
      const [rows] = await pool.query(
        `SELECT * FROM ${tableName} WHERE id = ?`,
        [req.body.id || result.insertId],
      );
      res.status(201).json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.put("/:id", async (req, res) => {
    try {
      await pool.query(`UPDATE ${tableName} SET ? WHERE id = ?`, [
        req.body,
        req.params.id,
      ]);
      const [rows] = await pool.query(
        `SELECT * FROM ${tableName} WHERE id = ?`,
        [req.params.id],
      );
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.delete("/:id", async (req, res) => {
    try {
      await pool.query(`DELETE FROM ${tableName} WHERE id = ?`, [
        req.params.id,
      ]);
      res.json({ message: "Deleted successfully" });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  return router;
};

// Health check
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    database: "mysql",
    timestamp: new Date().toISOString(),
  });
});

// Report data fetchers using Supabase REST API
const REPORT_QUERIES = {
  sales_summary: async (filters = {}) => {
    const supabaseFilter = buildSupabaseFilter(filters);
    const [schools, users, orders, schoolSales, orderItems] = await Promise.all(
      [
        supabaseRestQuery("schools", { select: "*", filter: supabaseFilter }),
        supabaseRestQuery("users", { select: "*" }),
        supabaseRestQuery("orders", { select: "*", filter: supabaseFilter }),
        supabaseRestQuery("school_sales", {
          select: "*",
          filter: supabaseFilter,
        }),
        supabaseRestQuery("order_items", { select: "*" }),
      ],
    );

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
    const supabaseFilter = buildSupabaseFilter(filters);
    const [schoolSales, users, schools] = await Promise.all([
      supabaseRestQuery("school_sales", {
        select: "*",
        filter: supabaseFilter,
      }),
      supabaseRestQuery("users", { select: "id, full_name, role" }),
      supabaseRestQuery("schools", { select: "id, name" }),
    ]);

    const userMap = Object.fromEntries(users?.map((u) => [u.id, u]) || []);
    const schoolMap = Object.fromEntries(schools?.map((s) => [s.id, s]) || []);

    const byStage = {};
    schoolSales?.forEach((sale) => {
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
    schoolSales?.forEach((sale) => {
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
      schoolSales
        ?.filter(
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
    const supabaseFilter = buildSupabaseFilter(filters);
    const [users, tasks, routePlans, visits, schools] = await Promise.all([
      supabaseRestQuery("users", { select: "*" }),
      supabaseRestQuery("tasks", { select: "*", filter: supabaseFilter }),
      supabaseRestQuery("route_plans", { select: "*", filter: supabaseFilter }),
      supabaseRestQuery("school_visits", {
        select: "*",
        filter: supabaseFilter,
      }),
      supabaseRestQuery("schools", { select: "id, name" }),
    ]);

    const schoolMap = Object.fromEntries(schools?.map((s) => [s.id, s]) || []);

    const agents =
      users
        ?.filter((u) => u.role === 4 || u.role === 5)
        .map((u) => {
          const userTasks = tasks?.filter((t) => t.assigned_to === u.id) || [];
          const userRoutes =
            routePlans?.filter((r) => r.assigned_to === u.id) || [];
          const userVisits = visits?.filter((v) => v.agent_id === u.id) || [];
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
    visits?.forEach((v) => {
      const key = `${v.agent_id}-${v.school_id}`;
      visitCounts[key] = (visitCounts[key] || 0) + 1;
    });
    const topSchools = Object.entries(visitCounts)
      .map(([key, count]) => {
        const [agentId, schoolId] = key.split("-");
        return {
          agent_name:
            users?.find((u) => u.id === agentId)?.full_name || "Unknown",
          school_name: schoolMap[schoolId]?.name || "Unknown",
          visits: count,
        };
      })
      .sort((a, b) => b.visits - a.visits)
      .slice(0, 20);

    return { agents, most_visited_schools: topSchools };
  },

  regional_summary: async (filters = {}) => {
    const supabaseFilter = buildSupabaseFilter(filters);
    const [regions, users, schools, sales] = await Promise.all([
      supabaseRestQuery("regions", { select: "*" }),
      supabaseRestQuery("users", { select: "*" }),
      supabaseRestQuery("schools", { select: "*", filter: supabaseFilter }),
      supabaseRestQuery("school_sales", {
        select: "*",
        filter: supabaseFilter,
      }),
    ]);

    const byRegion =
      regions?.map((r) => {
        const regionUsers = users?.filter((u) => u.region_id === r.id) || [];
        const regionSchools =
          schools?.filter((s) => s.region_id === r.id) || [];
        const regionSales = sales?.filter((s) => s.region_id === r.id) || [];
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
    const supabaseFilter = buildSupabaseFilter(filters);
    const [events, assignments, checkins, leads, samples, expenses] =
      await Promise.all([
        supabaseRestQuery("events", { select: "*", filter: supabaseFilter }),
        supabaseRestQuery("event_assignments", { select: "*" }),
        supabaseRestQuery("event_checkins", {
          select: "*",
          filter: supabaseFilter,
        }),
        supabaseRestQuery("event_leads", {
          select: "*",
          filter: supabaseFilter,
        }),
        supabaseRestQuery("event_samples", {
          select: "*",
          filter: supabaseFilter,
        }),
        supabaseRestQuery("event_expenses", {
          select: "*",
          filter: supabaseFilter,
        }),
      ]);

    const eventSummaries =
      events?.map((e) => {
        const eventAssignments =
          assignments?.filter((a) => a.event_id === e.id) || [];
        const eventCheckins =
          checkins?.filter((c) => c.event_id === e.id) || [];
        const eventLeads = leads?.filter((l) => l.event_id === e.id) || [];
        const eventSamples = samples?.filter((s) => s.event_id === e.id) || [];
        const eventExpenses =
          expenses?.filter((ex) => ex.event_id === e.id) || [];
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
    const supabaseFilter = buildSupabaseFilter(filters);
    const [users, distributions, orders, sales] = await Promise.all([
      supabaseRestQuery("users", { select: "*" }),
      supabaseRestQuery("school_sample_distributions", {
        select: "*",
        filter: supabaseFilter,
      }),
      supabaseRestQuery("orders", { select: "*", filter: supabaseFilter }),
      supabaseRestQuery("school_sales", {
        select: "*",
        filter: supabaseFilter,
      }),
    ]);

    const roi =
      users
        ?.filter((u) => u.role === 4 || u.role === 5)
        .map((u) => {
          const userDists =
            distributions?.filter((d) => d.agent_id === u.id) || [];
          const userOrders = orders?.filter((o) => o.agent_id === u.id) || [];
          const userSales = sales?.filter((s) => s.agent_id === u.id) || [];
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
    const supabaseFilter = buildSupabaseFilter(filters);
    const [targets, regions, users] = await Promise.all([
      supabaseRestQuery("targets", { select: "*", filter: supabaseFilter }),
      supabaseRestQuery("regions", { select: "*" }),
      supabaseRestQuery("users", { select: "id, full_name" }),
    ]);

    const regionMap = Object.fromEntries(regions?.map((r) => [r.id, r]) || []);
    const userMap = Object.fromEntries(users?.map((u) => [u.id, u]) || []);

    const formatted =
      targets?.map((t) => ({
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
app.get("/api/ai/data/:table", async (req, res) => {
  try {
    const { table } = req.params;
    const allowedTables = [
      "users",
      "schools",
      "tasks",
      "geofences",
      "route_plans",
      "school_sales",
      "opportunity_activities",
      "orders",
      "order_items",
      "school_visits",
      "school_follow_ups",
      "school_sample_distributions",
      "sample_requests",
      "catalog_items",
      "events",
      "event_assignments",
      "event_checkins",
      "event_leads",
      "event_samples",
      "event_expenses",
      "supervisor_alerts",
      "targets",
      "regions",
    ];

    if (!allowedTables.includes(table)) {
      return res.status(400).json({ error: `Table not allowed: ${table}` });
    }

    const limit = Math.min(parseInt(req.query.limit || "100", 10), 500);
    const offset = parseInt(req.query.offset || "0", 10);

    const [rows] = await pool.query(`SELECT * FROM ${table} LIMIT ? OFFSET ?`, [
      limit,
      offset,
    ]);
    res.json({ table, count: rows.length, data: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Register routes for main tables
const tables = ["users", "schools", "tasks", "geofences", "route_plans"];

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
