# Functional, Data-Flow, and RBAC Audit

## Scope and role mapping

The application is a Flutter client with an Express/MySQL API. The API uses numeric roles 1–5. Code labels role 1 Admin, 2 Sales Manager, and 3 BAS; other files use inconsistent labels for roles 4 and 5 (Agent / Grounds Person). Confirm the actual role mapping and intended policy with the product owner before treating a role name as authoritative. The inspected client uses regions and assigned-user IDs as data scopes; no general tenant identifier was evident in the inspected API routes.

This document defines an execution plan; it is not a claim that a live environment has been exercised. Use a disposable QA database with synthetic data only.

## Role-by-role matrix

Every role must be tested for its own profile, dashboard widgets, empty and populated lists, loading and failure states, and direct-ID access to an out-of-scope record. For every write, validate server-side authorization and scope, not only whether the client hides a control.

| Role | Dashboard/read coverage | Form/action coverage | Required boundary tests |
|---|---|---|---|
| 1 Admin | Admin dashboard (`/api/admin/dashboard`), users, schools, tasks, school sales, route plans, geofences, regions, targets, reports, orders | User/role management, tasks, routes, regions, targets, product/catalog, events, project forms, imports/uploads, delete confirmations | Test role assignment policy; test access to records outside a region/tenant according to approved admin policy |
| 2 Sales Manager | Manager dashboard, outreach, routes, team/agent performance, targets, attendance, pipeline, assigned work | Team-member creation (API permits requested roles 4/5), task/route assignment, sales/outreach updates | Attempt role 3/2 creation, user/record IDOR, cross-region read/write |
| 3 BAS | BAS dashboard cards: consignments, shops, regional coverage, reports, order approvals, team overview, command center, alerts/tasks, performance, events | Order approval and any exposed task/alert/consignment/event action | Attempt creation of roles 2/3/4, cross-region read/write and record reassignment |
| 4 Agent | Agent dashboard metrics, assigned routes, schools/shops, visits, orders, samples, check-ins, targets, profile | Visit/check-in, order checkout, sample distribution, follow-up, route progress, profile update | Read/write another agent's records by list filters and direct IDs; tamper owner/region fields |
| 5 Grounds Person | Verify actual dashboard route and role label first; inspect assigned work, profile, operational orders/consignments | Task completion/evidence, permitted operational/order actions, profile update | Read/write unassigned work and another user's records; test all hidden admin actions directly |

### Shared route inventory

Inventory every control and request for these route families. Generic table routes are mounted for `users`, `schools`, `tasks`, `geofences`, `route_plans`, `regions`, `region_assignments`, `catalog_items`, `orders`, `order_items`, `school_sales`, `school_visits`, `school_follow_ups`, `school_sample_distributions`, `messages`, `visit_checkins`, `sample_requests`, event tables, `targets`, `opportunity_activities`, `pipeline_history`, `project_forms`, `project_form_responses`, social tables, supervisor tables, audit/geofence events, task evidence, debt collections, visitations, consignments, and consignment items. Each has generic list/get/create/update/delete handlers.

Also inventory `/api/auth/*`, `/api/admin/team-members`, `/api/admin/dashboard`, `/api/orders/school-sale-checkout`, `/api/reports/*`, `/api/ai/*`, and `/api/upload/*`. For each widget capture endpoint, query/filter, expected schema, region/owner scope, loading UI, empty UI, and error UI. For each form capture method, path, payload schema, required and allowed fields, expected success and error codes, and post-submit UI state.

## Execution checklist

1. Seed one account for every role in two distinct regions/tenants. Seed owned, assigned, same-scope, and out-of-scope records. Record fixture IDs and expected visibility. Use synthetic names and data.
2. For every role, inspect every dashboard section and expand every widget, list, chart, profile, menu, modal, and confirmation. Record actual requests from browser/devtools or API logs. Add stable `data-testid` attributes to Flutter Web controls where practical.
3. Verify authorized reads return the documented status and schema, and only expected fixture rows. Test empty datasets and a delayed response; confirm empty copy and a visible loading state, then a clear error and retry path on failure.
4. Submit valid create/update actions. Assert method/path, exact relevant payload fields, authenticated identity, server-assigned owner/scope, response schema, persistence, success feedback, and refreshed widget. For delete, confirm cancellation preserves the row and confirmation removes only the selected row.
5. Submit missing/blank required values, malformed email/IDs/dates, invalid enums, duplicate keys, oversized inputs, and out-of-range values. Expect documented 4xx responses (commonly 400/409), useful field errors, no partial writes, and no stack traces or database messages in client responses.
6. In QA only, submit harmless injection strings such as `' OR '1'='1` and `<script>alert(1)</script>` to free-text fields. Check they remain literal data, do not broaden query results, render escaped, and never execute. Do not use destructive SQL payloads.
7. For every role, request out-of-scope list data and known out-of-scope record IDs. Tamper `id`, `user_id`, `agent_id`, `assigned_to`, `region_id`, role, and tenant fields in writes. Expect 403 or a policy-approved 404, and verify no state changed. Check missing, invalid, and expired credentials (401); check forbidden role operations (403).
8. Test network errors, timeouts, and server 5xx through a controlled QA proxy. Ensure loading terminates, errors are visible, retries do not duplicate writes, and failure never shows success.
9. Store a result per case: role, fixture, control/widget, request, status, sanitized response, expected/actual scope, UI result, and cleanup result. Never store bearer tokens or real personal data in artifacts.

## High-priority code-review findings to verify

These observations come from static inspection of `api/index.js`; confirm against the deployed build and intended policy. They are security findings, not successful runtime exploit tests.

| Observation | Evidence in source | QA/security implication |
|---|---|---|
| Generic table routers authenticate but do not apply role authorization or row/region scope. The same router exposes list, direct-ID read, create, update, patch, and delete for all mounted tables. | `createRouter()` and the `tables.forEach(... createRouter(table))` mount | Every role can attempt access to every table and record unless there is an uninspected upstream control. Exercise list and IDOR tests. Add server-side role and row-scope policy before relying on these routes for sensitive data. |
| AI data endpoint is not guarded by `verifyToken`. It returns raw rows from an allowlist that includes sensitive tables such as users, audit events, supervisor data, and orders. | `GET /api/ai/data/:table` | Anonymous disclosure risk. Verify without credentials; require auth and role/scope filtering or remove exposure. |
| AI report and chat handlers are not guarded by `verifyToken`; report queries can read broad datasets. | `POST /api/ai/report`, `POST /api/ai/chat` | Test anonymous access, cross-region leakage, rate/cost abuse, and prompt input handling. Enforce authentication, role/scope filtering, and quotas. |
| Public registration accepts a caller-selected role and inserts it directly. | `POST /api/auth/register` defaults role to 5 but uses body `role` | Attempt self-registration with role 1 and other privileged values. Restrict public registration to a fixed least-privilege role; provision privileged roles through authorized admin flow. |
| Generic CRUD silently drops unknown fields and may return 500 for schema/constraint errors; error messages include `error.message`. | Generic create/update/catch handlers | Validate payloads with explicit schemas and return safe 4xx errors. Ensure clients distinguish rejected writes from server failures and don't expose SQL details. |
| Upload path values are joined into filesystem paths; request scope and filename validation are not evident. | `/api/upload/:bucket/:path(*)` | Test traversal, filename normalization, content/size limits, and authorization in a sandbox. Store uploads outside static public paths or use controlled object storage and safe generated names. |
| School sale checkout checks token presence but no role and visible owner/scope checks. It returns 500 for validation/procedure failures. | `/api/orders/school-sale-checkout` | Verify role eligibility, order ownership, item/sale consistency, and error classification. Enforce transaction-safe server validation and return safe 4xx on invalid submissions. |
| Password reset returns the reset token in the HTTP response; the code comments that email delivery is not implemented. | `POST /api/auth/forgot-password` | In production this defeats the out-of-band reset factor. Send a short-lived single-use token only through a verified channel, never return it in the API body, and keep response content uniform for known/unknown accounts. |
| No login, registration, or reset throttling is visible in the inspected API setup. | Auth handlers and Express setup | Test rate limits and credential/reset abuse resistance; add per-account and per-IP controls with monitoring. |
| JWT secret has a hard-coded fallback. | `JWT_SECRET = process.env.JWT_SECRET || "dehus-secret-key-change-in-production"` | Fail startup when the secret is absent in production; rotate any environment that ever used the fallback. |
| Role-5 performance route requires a token but has no role check or region/user filter and returns aggregates for all role-5 users. | `GET /api/reports/role5-performance` | Test as every role against least-privilege policy. Restrict role and aggregate rows to permitted regions/teams. |
| API error handlers often return `error.message` to callers, including reports and generic CRUD. | API catch handlers | Check responses for SQL, schema, filesystem, and provider details. Log details server-side and return stable, safe error codes. |

## Playwright automation pattern

The Flutter client uses Dio and secure storage, so UI login/token persistence must be adapted to the actual Flutter Web build. Prefer a normal login through the UI for browser tests. The API-only portion below can independently validate role access. Keep credentials in CI secrets and fixture IDs in a disposable test database. Do not blindly click every submit control; use a reviewed manifest of safe, valid actions.

```ts
import { test, expect, request, type APIRequestContext } from '@playwright/test';

type Action = {
  testId: string;
  method: 'post' | 'put' | 'patch' | 'delete';
  path: string;
  status: number;
  // Valid, unique, disposable fixture. Do not put secrets in source control.
  responseCheck?: (body: any) => void;
};
type RoleSpec = {
  name: string;
  email: string;
  password: string;
  homePath: string;
  allowedReads: Array<{ path: string; check: (body: any) => void }>;
  forbiddenReads: string[]; // paths point to fixture records outside this role's scope
  actions: Action[];
};

declare function roleManifest(): RoleSpec[]; // Load from controlled CI fixtures.
declare function roleId(name: string): number;

for (const role of roleManifest()) {
  test(`${role.name}: reads, RBAC boundaries, and reviewed actions`, async ({ browser }) => {
    const api: APIRequestContext = await request.newContext({ baseURL: process.env.API_URL });
    const login = await api.post('/api/auth/login', {
      data: { email: role.email, password: role.password },
    });
    expect(login.status()).toBe(200);
    const { token, user } = await login.json();
    expect(user.role).toBe(roleId(role.name));

    for (const item of role.allowedReads) {
      const response = await api.get(item.path, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(response.status(), item.path).toBe(200);
      item.check(await response.json());
    }

    for (const path of role.forbiddenReads) {
      const response = await api.get(path, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect([403, 404], `out-of-scope ${path}`).toContain(response.status());
    }

    const page = await browser.newPage();
    // Adapt to real login flow and Flutter Web storage; do not inject production tokens.
    await page.goto(`${process.env.APP_URL}${role.homePath}`);
    await page.getByTestId('email').fill(role.email);
    await page.getByTestId('password').fill(role.password);
    await page.getByTestId('login-submit').click();
    await expect(page.getByTestId('dashboard-ready')).toBeVisible();

    for (const action of role.actions) {
      const [response] = await Promise.all([
        page.waitForResponse(r =>
          new URL(r.url()).pathname.endsWith(action.path) &&
          r.request().method().toLowerCase() === action.method
        ),
        page.getByTestId(action.testId).click(),
      ]);
      expect(response.status(), action.testId).toBe(action.status);
      if (response.status() !== 204 && action.responseCheck) {
        action.responseCheck(await response.json());
      }
    }
    await page.close();
    await api.dispose();
  });
}
```

Add separate tests for expected invalid-input 4xx responses, unauthenticated 401s, forbidden role/scope 403 or policy-approved 404s, and no state change after rejected writes. Successful writes alone should expect endpoint-contract statuses such as 200/201/204; do not globally treat 403 or 4xx as test failures when denial is expected.

### Read-only API smoke runner

`api/security_audit.js` is a runnable Node 18+ read-only probe. Set `API_URL` to a QA deployment and `QA_RBAC_CASES` to JSON containing role tokens and explicit allow/deny paths. Example shape (use secret environment injection in CI; do not paste real tokens in a shell history):

```json
[
  {
    "name": "Agent",
    "token": "<QA_TOKEN>",
    "allow": [
      { "path": "/api/auth/me", "statuses": [200] },
      { "path": "/api/schools?limit=10", "scope": { "regionField": "region_id", "regionId": "<AGENT_REGION_ID>" } }
    ],
    "deny": [
      { "path": "/api/admin/dashboard" },
      { "path": "/api/schools/<OUT_OF_SCOPE_SCHOOL_ID>" }
    ]
  }
]
```

The runner also checks that anonymous `GET /api/ai/data/users` is denied and never prints response records or tokens. Add a case per role and known out-of-scope fixture IDs. A successful 2xx list check can enforce owner/region fields, maximum row count, or absence of sensitive fields. Only use a designated QA environment; a failure on the anonymous AI probe means the endpoint returned data or otherwise did not return 401/403.

## Exit criteria

The audit passes only when every control/widget has a recorded test, successful requests match the contract and seeded data, empty/loading/error states are verified, unauthorized reads/writes disclose or change no protected data, and all high-priority findings are fixed or formally accepted with compensating controls.
