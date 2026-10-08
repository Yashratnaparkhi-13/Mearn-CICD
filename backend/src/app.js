const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const todoRoutes = require('./routes/todoRoutes');

const app = express();

// --- Global middleware ---
app.use(helmet());
app.use(cors());
app.use(express.json());
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// --- Health check endpoints (used by Kubernetes probes & load balancers) ---
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'mern-cicd-backend',
    version: process.env.APP_VERSION || 'dev',
    timestamp: new Date().toISOString(),
  });
});

app.get('/ready', (req, res) => {
  // In a real app you'd also check the DB connection state here.
  res.status(200).json({ status: 'ready' });
});

// --- API routes ---
app.use('/api/todos', todoRoutes);

// --- 404 handler ---
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// --- Centralized error handler ---
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
  });
});

module.exports = app;
