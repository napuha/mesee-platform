const fs = require('fs');
const http = require('http');
const path = require('path');

const root = path.resolve(__dirname, '..', '..', 'mesee-prototype');
const port = Number(process.env.MESEE_PORT || 8765);
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg' };

http.createServer((request, response) => {
  const relative = decodeURIComponent(request.url.split('?')[0] || '/');
  const file = path.resolve(root, relative === '/' ? 'index.html' : `.${relative}`);
  if (!file.startsWith(root)) { response.writeHead(403); return response.end('Forbidden'); }
  fs.readFile(file, (error, data) => {
    if (error) { response.writeHead(404); return response.end('Not found'); }
    response.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream' });
    response.end(data);
  });
}).listen(port, '127.0.0.1', () => console.log(`MeSee prototype: http://127.0.0.1:${port}`));
