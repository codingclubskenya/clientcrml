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

  const [views] = await conn.execute("SHOW FULL TABLES WHERE Table_type = 'VIEW'");
  console.log('Views on Contabo:');
  views.forEach(v => console.log('  ' + Object.values(v)[0]));

  const [procs] = await conn.execute('SHOW PROCEDURE STATUS WHERE Db = ?', [process.env.DB_NAME]);
  console.log('Procedures on Contabo:');
  procs.forEach(p => console.log('  ' + p.Name));

  const [funcs] = await conn.execute('SHOW FUNCTION STATUS WHERE Db = ?', [process.env.DB_NAME]);
  console.log('Functions on Contabo:');
  funcs.forEach(f => console.log('  ' + f.Name));

  await conn.end();
}

main().catch(e => console.error(e.message));
