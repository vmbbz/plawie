/**
 * glibc-compat.js - Aegis Native Compatibility Shim
 * Successor to bionic-bypass.js for Project Aegis Phase 1.
 */

const os = require('os');

// Fix for os.cpus() returning empty on Android 8+ SELinux
const originalCpus = os.cpus;
os.cpus = function () {
  const cpus = originalCpus.call(os);
  if (cpus.length === 0) {
    return [{ 
      model: 'ARMv8 Aegis Core', 
      speed: 2000, 
      times: { user: 0, nice: 0, sys: 0, idle: 100, irq: 0 } 
    }];
  }
  return cpus;
};

// Fix for os.networkInterfaces() EACCES or empty results
const originalNetworkInterfaces = os.networkInterfaces;
os.networkInterfaces = function () {
  const ifaces = originalNetworkInterfaces.call(os);
  if (Object.keys(ifaces).length === 0) {
    return { lo: [{ address: '127.0.0.1', family: 'IPv4' }] };
  }
  return ifaces;
};

console.log('🛡️ Project Aegis: glibc-compat.js initialized successfully');
