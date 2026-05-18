// Centralized paths for OpenClaw and Node.js binaries within the PRoot environment.
// This ensures "Industrial Grade" consistency across all services.

// The universal command to invoke OpenClaw.
// Use an absolute path so command execution does not depend on PATH state.
const String kOpenClawCommand = '/usr/local/bin/openclaw';

// Absolute paths (maintained for internal validation but no longer used for execution)
const String kNodeBinPath = '/usr/local/bin/node';
