// network-shim.js — fixes uv_interface_addresses EACCES 13 on Android PRoot
const os = require('os');
os.networkInterfaces = () => ({
  lo: [{ address: '127.0.0.1', netmask: '255.0.0.0', family: 'IPv4', mac: '00:00:00:00:00:00', internal: true, cidr: '127.0.0.1/8' }],
  eth0: [{ address: '192.168.1.100', netmask: '255.255.255.0', family: 'IPv4', mac: '00:11:22:33:44:55', internal: false, cidr: '192.168.1.100/24' }]
});
console.log('[SHIM] networkInterfaces patched for Android PRoot');
