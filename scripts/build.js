#!/usr/bin/env node
// Build step: copies index.html into ./public so static hosts (Vercel/Render/Railway)
// can serve a clean output directory. Idempotent and dependency-free.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'public');
const src = path.join(root, 'index.html');

if (!fs.existsSync(src)) {
  console.error('[build] index.html not found at repo root.');
  process.exit(1);
}

fs.mkdirSync(outDir, { recursive: true });
fs.copyFileSync(src, path.join(outDir, 'index.html'));

// Copy any static assets directory if present (future-proof).
const assetsDir = path.join(root, 'assets');
if (fs.existsSync(assetsDir)) {
  fs.cpSync(assetsDir, path.join(outDir, 'assets'), { recursive: true });
}

console.log('[build] wrote', path.join(outDir, 'index.html'));
