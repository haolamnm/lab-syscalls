#!/bin/bash

set -e

# 1) Clone xv6 source code if missing
if [ ! -d "xv6" ]; then
    echo "Cloning xv6 repository..."
    git clone --depth 10 git://g.csail.mit.edu/xv6-labs-2024 xv6
else
    echo "Skipping: xv6 repository already exists."
fi

# 2) Patch strict C signature warning in usertests.c
echo "Patching [usertests.c] signature..."
if grep -q '^rwsbrk()$' xv6/user/usertests.c; then
    sed -i 's/^rwsbrk()$/rwsbrk(char *s)/' xv6/user/usertests.c
    echo "  -> Updated rwsbrk() signature."
else
    echo "  -> Signature already patched."
fi

# 3) Add tracemask field to struct proc for trace syscall
echo "Patching [proc.h] tracemask field..."
if ! grep -q 'int tracemask;' xv6/kernel/proc.h; then
    sed -i '/char name\[16\]/a\  int tracemask;               // Syscall trace mask' xv6/kernel/proc.h
    echo "  -> Added tracemask field to struct proc."
else
    echo "  -> tracemask already exists."
fi

# Prepare provided syscall/command sources for integrate.sh
echo "Preparing source files for integration..."
mkdir -p commands syscalls

if [ -f "sysinfotest.c" ] && [ ! -f "commands/sysinfotest.c" ]; then
    cp sysinfotest.c commands/sysinfotest.c
    echo "  -> Copied sysinfotest.c to commands/."
fi

if [ -f "sysinfo.c" ] && [ ! -f "syscalls/sysinfo.c" ]; then
    cp sysinfo.c syscalls/sysinfo.c
    echo "  -> Copied sysinfo.c to syscalls/."
fi

echo ""
echo "Running integration step..."
bash ./integrate.sh

echo ""
echo "Patch completed successfully!"
