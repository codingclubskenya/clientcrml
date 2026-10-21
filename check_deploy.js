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
    
    w('echo "=== Deployed index.js - GET handler ==="');
    w('sed -n "305,375p" /home/devops/deheus-api/index.js 2>&1');
    w('echo ""');
    w('echo "=== Check if getTableColumns exists ==="');
    w('grep -n "getTableColumns" /home/devops/deheus-api/index.js 2>&1');
    w('echo ""');
    w('echo "=== Check line count ==="');
    w('wc -l /home/devops/deheus-api/index.js 2>&1');
    w('echo "=== DONE ==="');
    w('exit');
  });
}).on('error', (err) => { console.error('SSH error:', err.message); }).connect({
  host: '213.199.41.219', port: 22, username: 'devops', password: 'Kenyacom23', readyTimeout: 15000,
});
