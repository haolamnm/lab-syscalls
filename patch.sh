#!/bin/bash

set -e

# 1. Clone xv6 source code if isn't already there
if [ ! -d "xv6" ]; then
    echo "Cloning xv6 repository..."
    git clone --depth 10 git://g.csail.mit.edu/xv6-labs-2024 xv6
else
    echo "Skipping: xv6 repository already exists."
fi

# 2. Patch the strict C error on line 247
echo "Patching [usertests.c]..."
sed -i 's/^rwsbrk()$/rwsbrk(char *s)/' xv6/user/usertests.c

# 3. Inject tracemask into proc structure for trace syscall
echo "Patching [proc.h] for tracemask..."
if ! grep -q "int tracemask;" xv6/kernel/proc.h; then
    sed -i '/char name\[16\]/i\  int tracemask;            // Syscall trace bitmask' xv6/kernel/proc.h
    echo "  -> Added tracemask field to struct proc."
else
    echo "  -> tracemask already exists. Skipping."
fi

# Ensure expected source folders/files exist for integrate.sh
mkdir -p commands syscalls

if [ -f "sysinfotest.c" ] && [ ! -f "commands/sysinfotest.c" ]; then
    cp sysinfotest.c commands/sysinfotest.c
    echo "  -> Copied [sysinfotest.c] to commands/."
fi

if [ -f "sysinfo.c" ] && [ ! -f "syscalls/sysinfo.c" ]; then
    cp sysinfo.c syscalls/sysinfo.c
    echo "  -> Copied [sysinfo.c] to syscalls/."
fi

# 4. Patch proc.c tracemask lifecycle behavior
echo "Patching [proc.c] tracemask lifecycle..."
if ! awk '
    /static struct proc\*/ { in_allocproc = 0 }
    /allocproc\(void\)/ { in_allocproc = 1 }
    in_allocproc && /p->tracemask = 0;/ { found = 1 }
    in_allocproc && /return p;/ { in_allocproc = 0 }
    END { exit found ? 0 : 1 }
' xv6/kernel/proc.c; then
    sed -i '/p->state = USED;/a\  p->tracemask = 0;' xv6/kernel/proc.c
    echo "  -> Added tracemask init in allocproc()."
else
    echo "  -> allocproc() tracemask init already exists. Skipping."
fi

if ! awk '
    /^int$/ { in_fork = 0 }
    /fork\(void\)/ { in_fork = 1 }
    in_fork && /np->tracemask = p->tracemask;/ { found = 1 }
    in_fork && /return pid;/ { in_fork = 0 }
    END { exit found ? 0 : 1 }
' xv6/kernel/proc.c; then
    sed -i '/safestrcpy(np->name, p->name, sizeof(p->name));/a\  np->tracemask = p->tracemask;' xv6/kernel/proc.c
    echo "  -> Added tracemask inheritance in fork()."
else
    echo "  -> fork() tracemask inheritance already exists. Skipping."
fi

if ! awk '
    /static void$/ { in_freeproc = 0 }
    /freeproc\(struct proc \*p\)/ { in_freeproc = 1 }
    in_freeproc && /p->tracemask = 0;/ { found = 1 }
    in_freeproc && /p->state = UNUSED;/ { in_freeproc = 0 }
    END { exit found ? 0 : 1 }
' xv6/kernel/proc.c; then
    sed -i '/p->xstate = 0;/a\  p->tracemask = 0;' xv6/kernel/proc.c
    echo "  -> Added tracemask reset in freeproc()."
else
    echo "  -> freeproc() tracemask reset already exists. Skipping."
fi

# 5. Integrate custom syscalls/commands into freshly cloned xv6
echo "Running integration step..."
bash ./integrate.sh

# 6. Patch syscall.c to print traced syscall output
echo "Patching [syscall.c] trace output logic..."
if ! grep -q 'static char \*syscall_names\[\]' xv6/kernel/syscall.c; then
    DYNAMIC_NAMES=$(awk '/^#define SYS_/ {name=$2; sub(/^SYS_/, "", name); print "["$2"]   \"" tolower(name) "\","}' xv6/kernel/syscall.h)
    awk '
        BEGIN { in_syscalls = 0; inserted = 0 }
        /static uint64 \(\*syscalls\[\]\)\(void\) = \{/ { in_syscalls = 1 }
        {
            print
            if (in_syscalls && $0 ~ /^};$/ && !inserted) {
                print ""
                print "static char *syscall_names[] = {"
                print dyn
                print "};"
                inserted = 1
                in_syscalls = 0
            }
        }
    ' dyn="$DYNAMIC_NAMES" xv6/kernel/syscall.c > xv6/kernel/syscall.c.tmp
    mv xv6/kernel/syscall.c.tmp xv6/kernel/syscall.c
    echo "  -> Added syscall_names[] table."
else
    echo "  -> syscall_names[] table already exists. Skipping."
fi

# Remove malformed function-pointer entries accidentally placed in syscall_names[]
awk '
    /static char \*syscall_names\[\] = \{/ { in_names = 1 }
    in_names && /\[SYS_trace\][[:space:]]*sys_trace,/ { next }
    in_names && /\[SYS_hello\][[:space:]]*sys_hello,/ { next }
    in_names && /^};$/ { in_names = 0 }
    { print }
' xv6/kernel/syscall.c > xv6/kernel/syscall.c.tmp
mv xv6/kernel/syscall.c.tmp xv6/kernel/syscall.c

if ! grep -q 'p->tracemask >> num' xv6/kernel/syscall.c; then
    sed -i '/p->trapframe->a0 = syscalls\[num\]();/a\
\
    if(((p->tracemask >> num) \& 1) && num < NELEM(syscall_names) && syscall_names[num])\
      printf("%d: syscall %s -> %d\\n", p->pid, syscall_names[num], (int)p->trapframe->a0);' xv6/kernel/syscall.c
    echo "  -> Added trace print hook in syscall()."
else
    echo "  -> Trace print hook already exists. Skipping."
fi

# 7. Create kernel/ptree.h
if [ ! -f "xv6/kernel/ptree.h" ]; then
    cat << 'EOF' > xv6/kernel/ptree.h
#ifndef _PTREE_H_
#define _PTREE_H_

#include "types.h"

struct ptreeinfo {
    int pid;          // Process ID
    int ppid;         // Parent Process ID
    int state;        // Process State
    uint64 memsize;   // User memory size in bytes
    char name[16];    // Process Name
};

#endif
EOF
    echo "  -> Created [ptree.h] in xv6/kernel/"
fi

# 8. Append fetchptree() helper to kernel/proc.c
if ! grep -q "fetchptree" xv6/kernel/proc.c; then
    cat << 'EOF' >> xv6/kernel/proc.c

// fetchptree: collect info about all active processes.
// Returns the number of processes written on success.
// Returns -(count)-1 if the actual number of processes exceeds max (truncated).
// Returns -1 on copyout failure.

#include "ptree.h"

int
fetchptree(uint64 buf, int max)
{
  struct proc *p;
  struct ptreeinfo info;
  struct proc *caller = myproc();
  int count = 0;
  int truncated = 0;

  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state != UNUSED) {
      if (count < max) {
        struct proc *parent = p->parent;
        info.pid = p->pid;
        info.ppid = parent ? parent->pid : 0;
        info.state = p->state;
        info.memsize = p->sz;
        safestrcpy(info.name, p->name, sizeof(info.name));
        release(&p->lock);

        if (copyout(caller->pagetable, buf + count * sizeof(struct ptreeinfo),
                    (char *)&info, sizeof(struct ptreeinfo)) < 0) {
          return -1;
        }
        count++;
      } else {
        release(&p->lock);
        truncated = 1;
      }
    } else {
      release(&p->lock);
    }
  }

  if (truncated)
    return -count - 1;

  return count;
}
EOF
    echo "  -> Appended [fetchptree] helper to proc.c"
fi

# 9. Add fetchptree declaration to kernel/defs.h
if ! grep -q "fetchptree" xv6/kernel/defs.h; then
    if grep -q "procdump" xv6/kernel/defs.h; then
        sed -i '/void[[:space:]]*procdump(void);/a int             fetchptree(uint64, int);' xv6/kernel/defs.h
        echo "  -> Added [fetchptree] to defs.h"
    else
        echo "  !! Warning: procdump not found in defs.h. Add fetchptree declaration manually."
    fi
fi

# 10. Add ptree.h include to user/user.h
if ! grep -q "ptree.h" xv6/user/user.h; then
    sed -i '1i #include "../kernel/ptree.h"' xv6/user/user.h
    echo "  -> Added [#include ptree.h] to user.h"
fi

# 11. Inform the user about the patching process
echo "Patch completed successfully!"
