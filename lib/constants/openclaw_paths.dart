// Centralized paths for OpenClaw and Node.js binaries within the PRoot environment.
// This ensures "Industrial Grade" consistency across all services.

const String kOpenClawJsPath = '/usr/local/lib/node_modules/openclaw/bin/openclaw.js';
const String kNodeBinPath = '/usr/local/bin/node';

// Full absolute command to invoke OpenClaw reliably
const String kOpenClawCommand = '$kNodeBinPath $kOpenClawJsPath';
