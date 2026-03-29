const express = require('express');
const path = require('path');

const app = express();
const distPath = path.join(__dirname, 'dist');

// Static files from Vite build output
app.use(
  express.static(distPath, {
    index: false,
    maxAge: '1h',
  }),
);

// SPA fallback
app.get('*', (_req, res) => {
  res.sendFile(path.join(distPath, 'index.html'));
});

const parsedPort = Number.parseInt(process.env.PORT || '', 10);
const port = Number.isFinite(parsedPort) && parsedPort > 0 ? parsedPort : 4173;

app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend serving dist on port ${port}`);
});

