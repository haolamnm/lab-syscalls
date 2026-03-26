#!/bin/bash

set -e

# Ensure xv6 directory exists
if [ ! -d "xv6" ]; then
    echo "Error: xv6 folder not found."
    exit 1
fi

# ==========================================
# 1. INTEGRATE USER COMMANDS
# ==========================================
echo "Integrating custom commands into xv6..."
if [ -d "commands" ]; then
    for file in commands/*.c; do
        [ -e "$file" ] || continue

        filename=$(basename "$file")
        progname="${filename%.*}"

        # Link file to xv6/user/
        if [ -L "$(pwd)/xv6/user/$filename" ] || [ -f "$(pwd)/xv6/user/$filename" ]; then
            echo "  -> Skipping [$filename] (already exists in user/)."
        else
            ln -s "$(pwd)/commands/$filename" "$(pwd)/xv6/user/$filename"
            echo "  -> Linked [$filename] -> xv6/user/"
        fi

        # Register in Makefile
        if ! grep -q "\$U/_$progname" xv6/Makefile; then
            sed -i "/UPROGS=\\\\/a \\\t\$U\/_$progname\\\\" xv6/Makefile
            echo "  -> Registered [$progname] in Makefile."
        fi
    done
else
    echo "  -> No commands/ directory found. Skipping."
fi

echo ""

# ==========================================
# 2. INTEGRATE SYSTEM CALLS
# ==========================================
echo "Integrating custom syscalls into xv6..."
if [ -d "syscalls" ]; then
    # Find the current highest syscall number to auto-increment
    MAX_SYS=$(awk '/#define SYS_/ {print $3}' xv6/kernel/syscall.h | sort -nr | head -n 1)
    if [ -z "$MAX_SYS" ]; then MAX_SYS=21; fi

    for file in syscalls/*.c; do
        [ -e "$file" ] || continue

        syscall_name=$(basename "$file" .c)
        echo "Processing syscall: [$syscall_name]..."

        # Extract prototype from the magic comment
        PROTO=$(grep "^// PROTOTYPE:" "$file" | cut -d ':' -f 2- | sed 's/^[ \t]*//')
        if [ -z "$PROTO" ]; then
            PROTO="int $syscall_name(void);"
            echo "  -> No PROTOTYPE comment found. Defaulting to: $PROTO"
        fi

        # Add to user/user.h
        if ! grep -q "$PROTO" xv6/user/user.h; then
            sed -i "/int uptime(void);/a $PROTO" xv6/user/user.h
            echo "  -> Added [user.h] prototype."
        fi

        # Add to user/usys.pl
        if ! grep -q "entry(\"$syscall_name\");" xv6/user/usys.pl; then
            sed -i "/entry(\"uptime\");/a entry(\"$syscall_name\");" xv6/user/usys.pl
            echo "  -> Added [usys.pl] stub."
        fi

        # Add to kernel/syscall.h
        if ! grep -q "SYS_$syscall_name" xv6/kernel/syscall.h; then
            MAX_SYS=$((MAX_SYS + 1))
            sed -i "/#define SYS_close/a #define SYS_$syscall_name  $MAX_SYS" xv6/kernel/syscall.h
            echo "  -> Assigned SYS_$syscall_name as $MAX_SYS."
        fi

        # Add to kernel/syscall.c (routing)
        if ! grep -q "sys_$syscall_name(void);" xv6/kernel/syscall.c; then
            sed -i "/sys_close(void);/a extern uint64 sys_$syscall_name(void);" xv6/kernel/syscall.c
            echo "  -> Added [syscall.c] extern prototype."
        fi

        if ! grep -q "\[SYS_$syscall_name\][[:space:]]*sys_$syscall_name," xv6/kernel/syscall.c; then
            sed -i "/\[SYS_close\][[:space:]]*sys_close,/a \\\t[SYS_$syscall_name]   sys_$syscall_name," xv6/kernel/syscall.c
            echo "  -> Added [syscall.c] dispatch table entry."
        fi

        # Update implementation in kernel/sysproc.c
        START_MARKER="// --- BEGIN SYSCALL $syscall_name ---"
        END_MARKER="// --- END SYSCALL $syscall_name ---"

        # 1. Delete the old version if it exists
        if grep -Fq "$START_MARKER" xv6/kernel/sysproc.c; then
            sed -i "\|$START_MARKER|,\|$END_MARKER|d" xv6/kernel/sysproc.c
            echo "  -> Removed old implementation from [sysproc.c]."
        fi

        # 2. Inject the fresh version
        echo "" >> xv6/kernel/sysproc.c
        echo "$START_MARKER" >> xv6/kernel/sysproc.c
        grep -v "^// PROTOTYPE:" "$file" >> xv6/kernel/sysproc.c
        echo "$END_MARKER" >> xv6/kernel/sysproc.c
        echo "  -> Injected fresh implementation into [sysproc.c]."

    done
else
    echo "  -> No syscalls/ directory found. Skipping."
fi

echo ""

# ==========================================
# 3. APPLY SUPPORT PATCHES (SYSINFO)
# ==========================================
if grep -q "sys_sysinfo" xv6/kernel/sysproc.c; then
    echo "Applying support patches for sysinfo..."

    # 3.1 Create kernel/sysinfo.h if missing
    if [ ! -f "xv6/kernel/sysinfo.h" ]; then
        cat << 'EOF' > xv6/kernel/sysinfo.h
#ifndef _SYSINFO_H_
#define _SYSINFO_H_

#include "types.h"

struct sysinfo {
  uint64 freemem;
  uint64 nproc;
};

#endif
EOF
        echo "  -> Created [kernel/sysinfo.h]."
    fi

    # 3.2 Ensure sysproc.c includes sysinfo.h
    if ! grep -q '#include "sysinfo.h"' xv6/kernel/sysproc.c; then
        sed -i '/#include "proc.h"/a #include "sysinfo.h"' xv6/kernel/sysproc.c
        echo "  -> Added [#include \"sysinfo.h\"] to sysproc.c."
    fi

    # 3.3 Ensure user.h includes sysinfo.h for struct visibility
    if ! grep -q '#include "kernel/sysinfo.h"' xv6/user/user.h; then
        sed -i '/struct stat;/a #include "kernel/sysinfo.h"' xv6/user/user.h
        echo "  -> Added [#include \"kernel/sysinfo.h\"] to user.h."
    fi

    # 3.4 Ensure freemem/nproc prototypes exist in defs.h
    if ! grep -q 'freemem(void);' xv6/kernel/defs.h; then
        sed -i '/void            kinit(void);/a uint64          freemem(void);' xv6/kernel/defs.h
        echo "  -> Added [freemem] prototype to defs.h."
    fi
    if ! grep -q 'nproc(void);' xv6/kernel/defs.h; then
        sed -i '/void            procdump(void);/a uint64          nproc(void);' xv6/kernel/defs.h
        echo "  -> Added [nproc] prototype to defs.h."
    fi

    # 3.5 Ensure freemem() implementation exists
    if ! grep -q '^freemem(void)' xv6/kernel/kalloc.c; then
        cat << 'EOF' >> xv6/kernel/kalloc.c

uint64
freemem(void)
{
  struct run *r;
  uint64 n;

  acquire(&kmem.lock);
  n = 0;
  for(r = kmem.freelist; r; r = r->next)
    n += PGSIZE;
  release(&kmem.lock);
  return n;
}
EOF
        echo "  -> Added [freemem()] to kalloc.c."
    fi

    # 3.6 Ensure nproc() implementation exists
    if ! grep -q '^nproc(void)' xv6/kernel/proc.c; then
        cat << 'EOF' >> xv6/kernel/proc.c

uint64
nproc(void)
{
  struct proc *p;
  uint64 n;

  n = 0;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->state != UNUSED)
      n++;
    release(&p->lock);
  }
  return n;
}
EOF
        echo "  -> Added [nproc()] to proc.c."
    fi
fi

echo ""
echo "Integration complete! Run 'make qemu' inside the xv6 folder to test."
