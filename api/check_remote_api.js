const { Client } = require('ssh2');

const conn = new Client();

conn.on('ready', function () {
  console.log('SSH connection established');

  conn.exec('netstat -tlnp 2>/dev/null | grep ":3000" || echo "Port 3000 not listening"; echo "==="; curl -s http://127.0.0.1:3000/health 2>&1 || echo "API not running"; echo "==="; cat /home/devops/deheus-api/api/.env 2>/dev/null || echo "No .env in deheus-api"', function (err, stream) {
    if (err) {
      console.error('Exec error:', err);
      conn.end();
      return;
    }
    let output = '';
    stream.on('close', function () {
      console.log(output);
      conn.end();
    }).on('data', function (data) {
      output += data.toString();
    }).stderr.on('data', function (data) {
      output += data.toString();
    });
  });
}).on('error', function (err) {
  console.error('SSH error:', err.message);
}).connect({
  host: '213.199.41.219',
  port: 22,
  username: 'devops',
  password: 'Kenyacom23',
  readyTimeout: 15000
});
