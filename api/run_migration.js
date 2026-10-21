const mysql = require('mysql2/promise');
const fs = require('fs');
const dotenv = require('dotenv');
dotenv.config({ path: '.env' });

async function main() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: 3307,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectTimeout: 10000,
    multipleStatements: true
  });

  const sql = fs.readFileSync('../migration_002_views_procs.sql', 'utf8');

  // Remove DELIMITER statements and split by $$
  const cleaned = sql.replace(/DELIMITER\s+\S+/g, '');
  const statements = cleaned.split('$$').map(s => s.trim()).filter(s => s.length > 0);

  console.log('Executing ' + statements.length + ' statements...');

  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i].trim();
    if (!stmt) continue;
    try {
      await conn.query(stmt);
      console.log('  [' + (i + 1) + '/' + statements.length + '] OK');
    } catch (e) {
      console.error('  [' + (i + 1) + '/' + statements.length + '] ERROR:', e.message.substring(0, 100));
    }
  }

  // Verify
  const [views] = await conn.query("SHOW FULL TABLES WHERE Table_type = 'VIEW'");
  console.log('\nViews created:', views.map(v => Object.values(v)[0]).join(', '));

  const [funcs] = await conn.query('SHOW FUNCTION STATUS WHERE Db = ?', [process.env.DB_NAME]);
  console.log('Functions created:', funcs.map(f => f.Name).join(', '));

  const [procs] = await conn.query('SHOW PROCEDURE STATUS WHERE Db = ?', [process.env.DB_NAME]);
  console.log('Procedures created:', procs.map(p => p.Name).join(', '));

  await conn.end();
  console.log('\nMigration complete!');
}

main().catch(e => console.error(e.message));
