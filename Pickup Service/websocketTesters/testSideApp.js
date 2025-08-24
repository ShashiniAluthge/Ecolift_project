const WebSocket = require('ws');
const readline = require('readline');

const token = process.argv[2];
const role = process.argv[3];

const ws = new WebSocket('ws://localhost:5000');

ws.on('open', () => {
    ws.send(JSON.stringify({ token, role }));
});

ws.on('message', (message) => {
  const data = JSON.parse(message);
  console.log(`[${new Date().toLocaleTimeString()}] Incoming:`);
  console.dir(data, { depth: null });
});

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

rl.on('line', (line) => {
    if (line.trim().toLowerCase() === 'exit') {
        ws.close();
        process.exit(0);
    }

    ws.send(JSON.stringify({
        type: 'CHAT_MESSAGE',
        text: line.trim()
    }));

    console.log('You:', line.trim());
});
