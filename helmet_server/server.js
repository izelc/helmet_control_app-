const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

const sessions = [];

function logCommand({ user, command, timestamp }) {
  const entry = {
    user: user || 'anonymous',
    command,
    timestamp: timestamp || new Date().toISOString(),
  };
  sessions.push(entry);
  console.log("Logged:", entry);
}

app.post('/event', (req, res) => {
  const { user, command, timestamp } = req.body || {};

  if (!command) {
    return res.status(400).json({ error: "command is required" });
  }

  logCommand({ user, command, timestamp });
  return res.status(201).json({ status: "ok" });
});

['pair', 'start', 'pause', 'stop', 'continue'].forEach(cmd => {
  app.post(`/${cmd}`, (req, res) => {
    const { user, timestamp } = req.body || {};
    logCommand({ user, command: cmd, timestamp });
    res.status(201).json({ status: "ok" });
  });
});

app.get('/sessions', (req, res) => {
  res.json(sessions);
});

app.get('/', (req, res) => {
  res.send("Helmet log server running");
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});