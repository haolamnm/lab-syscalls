#!/bin/bash

# Automated test runner for xv6 syscalls
# Usage: ./test.sh
# This script builds xv6, boots QEMU, runs all test commands, captures output, and exits.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure we have a fresh build
echo "[*] Building xv6..."
make clean -C xv6 2>&1 > /dev/null
./integrate.sh
make -C xv6 fs.img 2>&1 > /dev/null

echo "[*] Build complete. Booting QEMU with tests..."

# Create a expect-like script to send commands to QEMU
# We use a named pipe approach
FIFO=$(mktemp -u)
mkfifo "$FIFO"

# Boot QEMU in background, redirecting serial to FIFO
timeout 120 make -C xv6 qemu 2>&1 < "$FIFO" | tee test_output.txt &
QEMU_PID=$!

# Give QEMU time to boot
sleep 3

# Send test commands to QEMU via the FIFO
{
  echo ""
  sleep 1
  echo "runalltests"
  echo ""
  sleep 10
  echo "tracetest"
  echo ""
  sleep 10
  echo "sysinfotest2"
  echo ""
  sleep 10
  echo "ptreetest"
  echo ""
  sleep 10
  echo "sysinfotest"
  echo ""
  sleep 5
  echo "pstree"
  echo ""
  sleep 5
  echo "trace 32 grep hello README"
  echo ""
  sleep 3
  echo "trace 2147483647 echo hello"
  echo ""
  sleep 3
  # Power off
  echo ""
  sleep 2
} > "$FIFO"

# Wait for QEMU to finish
wait $QEMU_PID 2>/dev/null || true

# Cleanup
rm -f "$FIFO"

echo ""
echo "[*] Test output saved to test_output.txt"
echo "[*] Done."
