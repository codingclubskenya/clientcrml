const { Client } = require('ssh2');
const conn = new Client();
conn.on('ready', () => {
  conn.exec('mysql -u longhorn -p3577 -h 213.199.41.219 longhorn -e "DESC users;"', (err, stream) => {
    if (err) { console.error(err); conn.end(); return; }
    let output = '';
    stream.on('close', () => { console.log(output); conn.end(); });
    stream.on('data', (d) => { output += d.toString(); });
    stream.stderr.on('data', (d) => { output += d.toString(); });
  });
}).on('error', (err) => { console.error('SSH error:', err.message); }).connect({
  host: '213.199.41.219', port: 22, username: 'devops', password: 'Kenyacom23', readyTimeout: 15000,
});
