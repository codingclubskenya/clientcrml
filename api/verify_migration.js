const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
dotenv.config({ path: '.env' });

async function main() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: 3307,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectTimeout: 10000
  });

  try {
    const [r] = await conn.execute('SELECT fn_role_id_from_text(?) as result', ['admin']);
    console.log('fn_role_id_from_text("admin") =', r[0].result);

    // Also check all views
    const [views] = await conn.query("SHOW FULL TABLES WHERE Table_type = 'VIEW'");
    console.log('All views:', views.map(v => Object.values(v)[0]).join(', '));

    // Check all functions
    const [funcs] = await conn.query('SHOW FUNCTION STATUS WHERE Db = ?', [process.env.DB_NAME]);
    console.log('All functions:', funcs.map(f => f.Name).join(', '));

    // Check all procedures
    const [procs] = await conn.query('SHOW PROCEDURE STATUS WHERE Db = ?', [process.env.DB_NAME]);
    console.log('All procedures:', procs.map(p => p.Name).join(', '));
  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    await conn.end();
  }
}

main().catch(e => console.error(e.message));
