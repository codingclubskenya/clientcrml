const { Client } = require('ssh2');

const conn = new Client();

conn.on('ready', function () {
  console.log('SSH connection established');

  conn.exec('cat /etc/nginx/sites-enabled/codingclubskenya.conf', function (err, stream) {
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
