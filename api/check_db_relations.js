const { Client } = require('ssh2');
const conn = new Client();

conn.on('ready', () => {
  conn.shell({ term: 'xterm-256color' }, (err, stream) => {
    if (err) { console.error(err); conn.end(); return; }
    let output = '';
    stream.on('close', () => { console.log(output); conn.end(); });
    stream.on('data', (d) => { output += d.toString(); });
    stream.stderr.on('data', (d) => { output += d.toString(); });

    const w = (cmd) => stream.write(cmd + '\n');
    
    w('echo "=== Total schools ==="');
    w("mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e \"SELECT COUNT(*) as total FROM schools;\" 2>&1");
    w('echo ""');
    w('echo "=== captured_by matching valid UUIDs ==="');
    w("mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e \"SELECT COUNT(*) as valid FROM schools WHERE captured_by REGEXP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';\" 2>&1");
    w('echo ""');
    w('echo "=== captured_by NOT matching valid UUIDs ==="');
    w("mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e \"SELECT COUNT(*) as invalid FROM schools WHERE captured_by IS NOT NULL AND captured_by != '' AND captured_by NOT REGEXP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';\" 2>&1");
    w('echo ""');
    w('echo "=== NULL or empty captured_by ==="');
    w("mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e \"SELECT COUNT(*) as empty FROM schools WHERE captured_by IS NULL OR captured_by = '';\" 2>&1");
    w('echo ""');
    w('echo "=== Schools per user (top 20) ==="');
    w("mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e \"SELECT u.id, u.full_name, u.email, COUNT(*) as school_count FROM schools s JOIN users u ON s.captured_by = u.id GROUP BY u.id ORDER BY school_count DESC LIMIT 20;\" 2>&1");
    w('echo ""');
    w('echo "=== Sample invalid captured_by values ==="');
    w("mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e \"SELECT id, name, captured_by FROM schools WHERE captured_by IS NOT NULL AND captured_by != '' AND captured_by NOT REGEXP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' LIMIT 5;\" 2>&1");
    w('echo ""');
    w('echo "=== DONE ==="');
    w('exit');
  });
}).on('error', (err) => { console.error('SSH error:', err.message); }).connect({
  host: '213.199.41.219', port: 22, username: 'devops', password: 'Kenyacom23', readyTimeout: 15000,
});
