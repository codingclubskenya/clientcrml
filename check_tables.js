const https = require('https');

function httpsGet(path, token) {
  return new Promise((resolve) => {
    const options = {
      hostname: 'codingclubskenya.com',
      port: 443,
      path: `/deheus-api${path}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    };
    const req = https.request(options, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch (e) { resolve({ status: res.statusCode, data: null, raw: data }); }
      });
    });
    req.on('error', resolve);
    req.end();
  });
}

const token = 'eyJ1c2VyX2lkIjoiMzRjZWM3MjEtMWM1MS00NzRkLWFmMTctMDg1Y2U3NGIzOWE0Iiwicm9lIjoxLCJleHAiOjE3OTIzMjExMDF9.mqHQXCT5tzn6PrOBrNekPMZ9mWljLeDBB6HkmpPvJhQ';

const apiTables = [
  "users", "schools", "tasks", "geofences", "route_plans", "regions", "region_assignments",
  "catalog_items",
  "orders", "order_items", "school_sales", "school_visits", "school_follow_ups", "school_sample_distributions",
  "messages",
  "visit_checkins", "sample_requests",
  "events", "event_assignments", "event_checkins", "event_tasks", "event_leads", "event_orders", "event_sales", "event_samples", "event_photos", "event_expenses", "event_reports",
  "targets", "opportunity_activities", "pipeline_history",
  "project_forms", "project_form_responses",
  "social_conversations", "social_messages",
  "supervisor_alerts", "supervisor_incidents", "supervisor_notes", "supervisor_notifications", "audit_events", "geofence_events",
  "task_completion_evidence",
  "debt_collections",
  "consignments", "consignment_items",
  "visitations",
];

(async () => {
  for (const table of apiTables) {
    const res = await httpsGet(`/api/${table}?limit=1`, token);
    const exists = res.status === 200 || res.status === 404;
    const hasData = res.status === 200 && Array.isArray(res.data);
    const hasError = res.status === 500;
    console.log(`${table}: ${res.status} ${hasData ? `(data: ${res.data.length})` : hasError ? res.raw?.substring(0, 80) : ''}`);
  }
})();
