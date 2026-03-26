#!/bin/bash

# Ensure the script stops if any command fails
set -e

# Function to display help
show_help() {
    echo "Usage: ./run.sh [command]"
    echo ""
    echo "Commands:"
    echo "  qemu      - Integrates code and boots xv6 in QEMU"
    echo "  clean     - Cleans the xv6 build environment"
    echo "  fresh     - Cleans, integrates, and boots QEMU (clean start)"
    echo ""
}

# Check if xv6 exists before trying to run commands inside it
if [ ! -d "xv6" ]; then
    echo "Error: xv6 folder not found. Run ./patch.sh first."
    exit 1
fi

case "$1" in
    qemu)
        ./integrate.sh
        cd xv6 && make qemu
        ;;
    clean)
        echo "Cleaning xv6 build..."
        cd xv6 && make clean
        ;;
    fresh)
        echo "Performing a fresh build..."
        cd xv6 && make clean
        cd ..
        ./integrate.sh
        cd xv6 && make qemu
        ;;
    *)
        show_help
        ;;
esac
