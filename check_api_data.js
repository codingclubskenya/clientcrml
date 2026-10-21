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

    w('echo "=== Users table columns ==="');
    w('mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e "SHOW COLUMNS FROM users;" 2>&1');
    w('echo ""');
    w('echo "=== Test login ==="');
    w('curl -s -X POST http://127.0.0.1:3000/api/auth/login -H "Content-Type: application/json" -d \'{"email":"admin2@test.com","password":"admin123"}\' 2>&1');
    w('echo ""');
    w('echo "=== GET users ==="');
    w("TOKEN=$(curl -s -X POST http://127.0.0.1:3000/api/auth/login -H \"Content-Type: application/json\" -d '{\"email\":\"admin2@test.com\",\"password\":\"admin123\"}' | node -e \"let d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>{try{console.log(JSON.parse(Buffer.concat(d).toString()).token)}catch(e){console.log('ERROR',e.message)}})\")");
    w('curl -s "http://127.0.0.1:3000/api/users?limit=3&orderBy=created_at&orderDir=ASC" -H "Authorization: Bearer $TOKEN" 2>&1');
    w('echo ""');
    w('echo "=== GET schools ==="');
    w('curl -s "http://127.0.0.1:3000/api/schools?limit=3&orderBy=created_at&orderDir=ASC" -H "Authorization: Bearer $TOKEN" 2>&1');
    w('echo ""');
    w('echo "=== DONE ==="');
    w('exit');
  });
}).on('error', (err) => { console.error('SSH error:', err.message); }).connect({
  host: '213.199.41.219', port: 22, username: 'devops', password: 'Kenyacom23', readyTimeout: 15000,
});
