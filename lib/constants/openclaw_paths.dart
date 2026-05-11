// Centralized paths for OpenClaw and Node.js binaries within the PRoot environment.
// This ensures "Industrial Grade" consistency across all services.

// The universal command to invoke OpenClaw (uses the wrapper created by BootstrapManager)
const String kOpenClawCommand = 'openclaw';

// Absolute paths (maintained for internal validation but no longer used for execution)
const String kNodeBinPath = '/usr/local/bin/node';
