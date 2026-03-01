#!/system/bin/sh
# Wrapper script to bypass libtalloc dependency
export LD_PRELOAD=""
exec "$0.bin" "$@"
