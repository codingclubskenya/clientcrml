// Read-only RBAC smoke audit. Requires Node 18+ (built-in fetch).
// Usage (PowerShell):
//   $env:API_URL = 'https://qa.example.test'
//   $env:QA_RBAC_CASES = '[{"name":"Agent","token":"...","allow":[{"path":"/api/auth/me"}],"deny":[{"path":"/api/admin/dashboard"}]}]'
//   node api/security_audit.js
// Supply only disposable QA tokens and fixture IDs. Never commit this JSON or
// print tokens. The script performs GET requests only.

const baseUrl = (process.env.API_URL || '').replace(/\/$/, '');
if (!baseUrl) {
  console.error('Set API_URL to the designated QA API base URL.');
  process.exit(2);
}

let cases = [];
try {
  cases = JSON.parse(process.env.QA_RBAC_CASES || '[]');
  if (!Array.isArray(cases)) throw new Error('must be a JSON array');
} catch (error) {
  console.error(`Invalid QA_RBAC_CASES: ${error.message}`);
  process.exit(2);
}

const findings = [];
const checks = [];

async function get(path, token) {
  const response = await fetch(new URL(path, `${baseUrl}/`), {
    method: 'GET',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    redirect: 'manual',
    signal: AbortSignal.timeout(15000),
  });
  let body;
  try { body = await response.json(); } catch { body = null; }
  return { status: response.status, body };
}

function record(label, ok, detail) {
  checks.push({ label, ok, detail });
  if (!ok) findings.push({ label, detail });
}

function withinExpectation(body, expected) {
  // Optional assertion for array APIs or { data: [...] } endpoints.
  if (!expected) return true;
  const rows = Array.isArray(body) ? body : body?.data;
  if (!Array.isArray(rows)) return false;
  if (expected.maxRows !== undefined && rows.length > expected.maxRows) return false;
  if (expected.ownerField && expected.ownerId !== undefined &&
      rows.some(row => String(row?.[expected.ownerField]) !== String(expected.ownerId))) return false;
  if (expected.regionField && expected.regionId !== undefined &&
      rows.some(row => String(row?.[expected.regionField]) !== String(expected.regionId))) return false;
  if (expected.forbidFields?.some(field => rows.some(row => field in (row || {})))) return false;
  return true;
}

async function main() {
  // This GET directly checks a high-risk unauthenticated data route identified
  // in source review. It does not print returned user data.
  try {
    const anon = await get('/api/ai/data/users');
    record('anonymous /api/ai/data/users denied', anon.status === 401 || anon.status === 403,
      `HTTP ${anon.status}; expected 401 or 403`);
  } catch (error) {
    record('anonymous /api/ai/data/users reachable', false, error.name || 'request failed');
  }

  for (const role of cases) {
    if (!role?.name || !role?.token) {
      record('role case configuration', false, 'Each role case needs name and token.');
      continue;
    }
    const headers = role.token;
    for (const route of role.allow || []) {
      try {
        const result = await get(route.path, headers);
        const statusOk = (route.statuses || [200]).includes(result.status);
        const scopeOk = result.status < 200 || result.status >= 300 ||
          withinExpectation(result.body, route.scope);
        record(`${role.name} allow ${route.path}`, statusOk && scopeOk,
          `HTTP ${result.status}; ${scopeOk ? 'scope/schema expectation passed' : 'scope/schema expectation failed'}`);
      } catch (error) {
        record(`${role.name} allow ${route.path}`, false, error.name || 'request failed');
      }
    }
    for (const route of role.deny || []) {
      try {
        const result = await get(route.path, headers);
        const expected = route.statuses || [403, 404];
        const denied = expected.includes(result.status);
        record(`${role.name} deny ${route.path}`, denied,
          `HTTP ${result.status}; expected ${expected.join(' or ')}`);
      } catch (error) {
        record(`${role.name} deny ${route.path}`, false, error.name || 'request failed');
      }
    }
  }

  for (const check of checks) {
    console.log(`${check.ok ? 'PASS' : 'FAIL'} ${check.label}: ${check.detail}`);
  }
  console.log(`\n${checks.filter(x => x.ok).length}/${checks.length} checks passed; ${findings.length} finding(s).`);
  if (findings.length) process.exitCode = 1;
}

main().catch(error => {
  console.error(`Audit runner failed: ${error.message}`);
  process.exitCode = 2;
});
