const http = require('http');

const port = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <html>
      <body style="font-family: sans-serif; text-align: center; margin-top: 100px; background: #D83B01; color: white;">
        <h1>Hello from STAGING</h1>
        <p>Azure App Service — AZ-104 Project by Sadia</p>
      </body>
    </html>
  `);
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
