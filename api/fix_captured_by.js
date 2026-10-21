const fs = require('fs');
const { Client } = require('ssh2');

const conn = new Client();

// Load mappings from CSV analysis
const mappings = JSON.parse(fs.readFileSync('../csv_to_fixture.json', 'utf8'));
console.log('Loaded ' + mappings.length + ' school->user mappings to fix');

// Build a single SQL UPDATE using a case statement
// Group by user_id for efficiency
const byUser = {};
for (const m of mappings) {
  if (!byUser[m.cb]) byUser[m.cb] = [];
  byUser[m.cb].push(m.sid);
}

const w = (cmd, shellStream) => shellStream.write(cmd + '\n');

conn.on('ready', () => {
  console.log('SSH connection established');
  conn.shell({ term: 'xterm-256color' }, (err, stream) => {
    if (err) { console.error('Shell error:', err); conn.end(); return; }
    let output = '';
    stream.on('close', () => { console.log(output); conn.end(); });
    stream.on('data', (d) => { output += d.toString(); });
    stream.stderr.on('data', (d) => { output += d.toString(); });

    const mysql = 'mysql -u longhorn -p3577 -h 213.199.41.219 longhorn';

    // Start transaction
    w('echo "=== Updating captured_by values ==="', stream);
    w(`${mysql} << 'SQLEOF'`, stream);
    w('START TRANSACTION;', stream);

    // Create a temp table for the update
    w('CREATE TEMPORARY TABLE IF NOT EXISTS tmp_school_user_map (sid VARCHAR(255) PRIMARY KEY, uid VARCHAR(255));', stream);
    w('TRUNCATE TABLE tmp_school_user_map;', stream);

    // Insert values in batches
    const batchSize = 200;
    for (let i = 0; i < mappings.length; i += batchSize) {
      const batch = mappings.slice(i, i + batchSize);
      const values = batch.map(m => `('${m.sid}', '${m.cb}')`).join(', ');
      w(`INSERT INTO tmp_school_user_map (sid, uid) VALUES ${values} ON DUPLICATE KEY UPDATE uid=VALUES(uid);`, stream);
    }

    // Update schools table, joining on the temp table
    w(`UPDATE schools s JOIN tmp_school_user_map m ON s.id = m.sid SET s.captured_by = m.uid;`, stream);

    // Drop temp table
    w('DROP TEMPORARY TABLE tmp_school_user_map;', stream);

    // Verify: count schools per user
    w(`SELECT u.full_name, COUNT(*) as school_count FROM schools s JOIN users u ON s.captured_by = u.id GROUP BY u.id ORDER BY school_count DESC LIMIT 20;`, stream);

    // Count schools with matched vs unmatched captured_by
    w(`SELECT 'matched_to_real_user' as status, COUNT(*) as count FROM schools s JOIN users u ON s.captured_by = u.id WHERE u.id != '11111111-1111-1111-1111-111111111111';`, stream);
    w(`SELECT 'fallback_user' as status, COUNT(*) as count FROM schools WHERE captured_by = '11111111-1111-1111-1111-111111111111';`, stream);
    w(`SELECT 'total' as status, COUNT(*) as count FROM schools;`, stream);

    w('COMMIT;', stream);
    w('SQLEOF', stream);
    w('echo "=== DONE ==="', stream);
    w('exit', stream);
  });
}).on('error', (err) => {
  console.error('SSH error:', err.message);
}).connect({
  host: '213.199.41.219', port: 22, username: 'devops', password: 'Kenyacom23', readyTimeout: 15000,
});
