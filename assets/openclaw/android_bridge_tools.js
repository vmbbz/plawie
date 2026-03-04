#!/usr/bin/env node

/**
 * OpenClaw Android Bridge Tools
 * Maps OpenClaw tool calls to the AndroidBridgeServer running on localhost:8765.
 * This skips the Flutter method channels entirely, matching SeekerClaw's IPC architecture.
 */

const http = require('http');

async function androidBridgeCall(endpoint, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: 8765,
      path: endpoint,
      method: method,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(JSON.parse(body || '{}'));
          } else {
            reject(new Error(`Bridge error ${res.statusCode}: ${body}`));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);

    if (data && (method === 'POST' || method === 'PUT')) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// OpenClaw Tool Interface
module.exports = {
  get_battery: async () => {
    try {
      const res = await androidBridgeCall('/battery');
      return `Battery level: ${res.level}%\nCharging: ${res.isCharging}`;
    } catch (e) {
      return `Failed to read battery: ${e.message}`;
    }
  },

  vibrate: async (durationMs = 200) => {
    try {
      await androidBridgeCall('/vibrate', 'POST', { durationMs });
      return `Vibrated for ${durationMs}ms`;
    } catch (e) {
      return `Failed to vibrate: ${e.message}`;
    }
  },

  read_sensor: async (type = 'accelerometer') => {
    try {
      const res = await androidBridgeCall(`/sensor?type=${type}`);
      return JSON.stringify(res, null, 2);
    } catch (e) {
      return `Failed to read sensor ${type}: ${e.message}`;
    }
  }
};
