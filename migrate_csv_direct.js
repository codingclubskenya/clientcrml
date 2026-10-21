/**
 * Direct MySQL migration script for CSV data
 * Run this on the Contabo server:
 *   cd /home/devops/deheus-api
 *   node /home/devops/migrate_csv_direct.js
 *
 * This bypasses the API and connects directly to MySQL,
 * avoiding column mismatch issues.
 */

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

const pool = mysql.createPool({
  host: 'localhost',
  port: 3306,
  user: 'longhorn',
  password: '3577',
  database: 'longhorn',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

function parseCsv(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n').filter(l => l.trim());
  const headers = parseCsvLine(lines[0]);
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const values = parseCsvLine(lines[i]);
    const row = {};
    headers.forEach((h, idx) => { row[h] = values[idx] !== undefined ? values[idx] : null; });
    rows.push(row);
  }
  return rows;
}

function parseCsvLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') { current += '"'; i++; }
      else { inQuotes = !inQuotes; }
    } else if (ch === ',' && !inQuotes) { result.push(current); current = ''; }
    else { current += ch; }
  }
  result.push(current);
  return result;
}

function cleanValue(val) {
  if (val === null || val === undefined || val === '') return null;
  if (val.toLowerCase() === 'true') return 1;
  if (val.toLowerCase() === 'false') return 0;
  if (val.toLowerCase() === 'null') return null;
  return val;
}

function cleanDate(val) {
  if (!val) return null;
  try {
    const d = new Date(val);
    return d.toISOString().slice(0, 19).replace('T', ' ');
  } catch {
    return null;
  }
}

function numOrNull(val) {
  if (val === null || val === undefined || val === '') return null;
  const n = parseFloat(val);
  return isNaN(n) ? null : n;
}

async function importUsers() {
  const csvPath = path.join(__dirname, 'users_rows.csv');
  if (!fs.existsSync(csvPath)) { console.log('users_rows.csv not found'); return { inserted: 0, skipped: 0 }; }
  const rows = parseCsv(csvPath);
  console.log(`Importing ${rows.length} users...`);

  let inserted = 0, skipped = 0;
  for (const row of rows) {
    const id = cleanValue(row.id);
    const email = cleanValue(row.email);
    if (!id || !email) { skipped++; continue; }

    const isSyncedVal = cleanValue(row.isSynced);
    const cols = {
      id, email, full_name: cleanValue(row.full_name), phone: cleanValue(row.phone),
      role: parseInt(cleanValue(row.role) || '5', 10),
      isSynced: (isSyncedVal === 1 || isSyncedVal === true || isSyncedVal === 'true') ? 1 : 0,
      region: cleanValue(row.region),
      region_id: cleanValue(row.region_id),
      sub_region: cleanValue(row.sub_region),
      role_ref: cleanValue(row.role_ref),
      created_at: cleanDate(row.created_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
      updated_at: cleanDate(row.updated_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
    };

    try {
      const colNames = Object.keys(cols);
      const placeholders = colNames.map(() => '?').join(', ');
      const values = colNames.map(k => cols[k]);
      await pool.execute(
        `INSERT INTO users (${colNames.map(c => `\`${c}\``).join(', ')}) VALUES (${placeholders})`,
        values
      );
      inserted++;
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') skipped++;
      else { console.error(`User ${email}: ${err.message}`); skipped++; }
    }
  }
  console.log(`Users: ${inserted} inserted, ${skipped} skipped`);
  return { inserted, skipped };
}

async function importSchools() {
  const csvPath = path.join(__dirname, '12.csv');
  if (!fs.existsSync(csvPath)) { console.log('12.csv not found'); return { inserted: 0, skipped: 0 }; }
  const rows = parseCsv(csvPath);
  console.log(`Importing ${rows.length} schools...`);

  let inserted = 0, skipped = 0;
  for (const row of rows) {
    const id = cleanValue(row.id);
    const name = cleanValue(row.name);
    if (!id || !name) { skipped++; continue; }

    let focusAreasJson = null;
    const fa = cleanValue(row.focusAreas);
    if (fa) {
      try { focusAreasJson = JSON.stringify(JSON.parse(fa)); } catch { focusAreasJson = null; }
    }

    const isSyncedVal = cleanValue(row.isSynced);
    const cols = {
      id, name,
      phone: cleanValue(row.phone),
      county: cleanValue(row.county),
      source: cleanValue(row.source),
      external_place_id: cleanValue(row.external_place_id),
      external_vicinity: cleanValue(row.external_vicinity),
      focusAreas: focusAreasJson,
      book_category: cleanValue(row.book_category),
      dealer_type: cleanValue(row.dealer_type),
      shop_category: cleanValue(row.shop_category),
      selected_product: cleanValue(row.selected_product),
      partner_subtype: cleanValue(row.partner_subtype),
      latitude: numOrNull(row.latitude),
      longitude: numOrNull(row.longitude),
      gps_accuracy_meters: numOrNull(row.gps_accuracy_meters),
      photo_url: cleanValue(row.photo_url),
      photo_path: cleanValue(row.photo_path),
      captured_by: cleanValue(row.captured_by),
      captured_at: cleanDate(row.captured_at),
      capture_status: cleanValue(row.capture_status),
      contact_name: cleanValue(row.contact_name),
      contact_phone: cleanValue(row.contact_phone),
      contact_title: cleanValue(row.contact_title),
      feedback: cleanValue(row.feedback),
      notes: cleanValue(row.notes),
      samples_left: cleanValue(row.samples_left),
      sample_book: cleanValue(row.sample_book),
      school_ownership: cleanValue(row.school_ownership),
      school_ownership_other: cleanValue(row.school_ownership_other),
      school_population: cleanValue(row.school_population),
      school_lifecycle_status: cleanValue(row.school_lifecycle_status),
      engagement_type: cleanValue(row.engagement_type),
      sample_proof_url: cleanValue(row.sample_proof_url),
      sample_proof_path: cleanValue(row.sample_proof_path),
      isSynced: (isSyncedVal === 1 || isSyncedVal === true || isSyncedVal === 'true') ? 1 : 0,
      created_at: cleanDate(row.created_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
      updated_at: cleanDate(row.updated_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
    };

    try {
      const colNames = Object.keys(cols);
      const placeholders = colNames.map(() => '?').join(', ');
      const values = colNames.map(k => cols[k]);
      await pool.execute(
        `INSERT INTO schools (${colNames.map(c => `\`${c}\``).join(', ')}) VALUES (${placeholders})`,
        values
      );
      inserted++;
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') skipped++;
      else { console.error(`School ${id}: ${err.message}`); skipped++; }
    }
  }
  console.log(`Schools: ${inserted} inserted, ${skipped} skipped`);
  return { inserted, skipped };
}

async function importSchoolSales() {
  const csvPath = path.join(__dirname, 'school_sales_rows.csv');
  if (!fs.existsSync(csvPath)) { console.log('school_sales_rows.csv not found'); return { inserted: 0, skipped: 0 }; }
  const rows = parseCsv(csvPath);
  console.log(`Importing ${rows.length} school_sales...`);

  let inserted = 0, skipped = 0;
  for (const row of rows) {
    const id = cleanValue(row.id);
    if (!id) { skipped++; continue; }

    const isSyncedVal = cleanValue(row.isSynced);
    const cols = {
      id,
      school_id: cleanValue(row.school_id),
      agent_id: cleanValue(row.agent_id),
      package_name: cleanValue(row.package_name),
      expected_value: numOrNull(row.expected_value),
      notes: cleanValue(row.notes),
      sale_status: cleanValue(row.sale_status) || 'lead',
      stage_contact_person: cleanValue(row.stage_contact_person),
      sample_quantity: numOrNull(row.sample_quantity),
      quotation_reference: cleanValue(row.quotation_reference),
      decision_owner: cleanValue(row.decision_owner),
      negotiation_topic: cleanValue(row.negotiation_topic),
      loss_reason: cleanValue(row.loss_reason),
      dormant_reason: cleanValue(row.dormant_reason),
      stage_updated_at: cleanDate(row.stage_updated_at),
      expected_close_date: cleanDate(row.expected_close_date),
      probability: numOrNull(row.probability) || 0,
      closed_at: cleanDate(row.closed_at),
      next_action: cleanValue(row.next_action),
      next_action_date: cleanDate(row.next_action_date),
      last_activity_at: cleanDate(row.last_activity_at),
      risk_level: cleanValue(row.risk_level) || 'low',
      weighted_forecast: numOrNull(row.weighted_forecast) || 0,
      stage_sla_due_at: cleanDate(row.stage_sla_due_at),
      isSynced: (isSyncedVal === 1 || isSyncedVal === true || isSyncedVal === 'true') ? 1 : 0,
      created_at: cleanDate(row.created_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
      updated_at: cleanDate(row.updated_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
    };

    try {
      const colNames = Object.keys(cols);
      const placeholders = colNames.map(() => '?').join(', ');
      const values = colNames.map(k => cols[k]);
      await pool.execute(
        `INSERT INTO school_sales (${colNames.map(c => `\`${c}\``).join(', ')}) VALUES (${placeholders})`,
        values
      );
      inserted++;
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') skipped++;
      else { console.error(`School sale ${id}: ${err.message}`); skipped++; }
    }
  }
  console.log(`School sales: ${inserted} inserted, ${skipped} skipped`);
  return { inserted, skipped };
}

async function importFollowUps() {
  const csvPath = path.join(__dirname, 'school_follow_ups_rows.csv');
  if (!fs.existsSync(csvPath)) { console.log('school_follow_ups_rows.csv not found'); return { inserted: 0, skipped: 0 }; }
  const rows = parseCsv(csvPath);
  console.log(`Importing ${rows.length} opportunity_activities...`);

  let inserted = 0, skipped = 0;
  for (const row of rows) {
    const id = cleanValue(row.id);
    if (!id) { skipped++; continue; }

    const cols = {
      id,
      opportunity_id: cleanValue(row.agent_id) || cleanValue(row.school_id),
      school_id: cleanValue(row.school_id),
      actor_id: cleanValue(row.agent_id),
      activity_type: 'follow_up',
      activity_outcome: cleanValue(row.follow_up_status),
      notes: cleanValue(row.notes),
      next_action: cleanValue(row.next_step),
      next_action_date: cleanDate(row.due_at),
      created_at: cleanDate(row.created_at) || new Date().toISOString().slice(0, 19).replace('T', ' '),
    };

    try {
      const colNames = Object.keys(cols);
      const placeholders = colNames.map(() => '?').join(', ');
      const values = colNames.map(k => cols[k]);
      await pool.execute(
        `INSERT INTO opportunity_activities (${colNames.map(c => `\`${c}\``).join(', ')}) VALUES (${placeholders})`,
        values
      );
      inserted++;
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') skipped++;
      else { console.error(`Follow-up ${id}: ${err.message}`); skipped++; }
    }
  }
  console.log(`Follow-ups: ${inserted} inserted, ${skipped} skipped`);
  return { inserted, skipped };
}

async function main() {
  console.log('Connecting to MySQL...');
  let totalInserted = 0, totalSkipped = 0;

  const u = await importUsers();
  totalInserted += u.inserted; totalSkipped += u.skipped;

  const s = await importSchools();
  totalInserted += s.inserted; totalSkipped += s.skipped;

  const ss = await importSchoolSales();
  totalInserted += ss.inserted; totalSkipped += ss.skipped;

  const f = await importFollowUps();
  totalInserted += f.inserted; totalSkipped += f.skipped;

  console.log(`\nMigration complete! Total: ${totalInserted} inserted, ${totalSkipped} skipped`);
  process.exit(0);
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
