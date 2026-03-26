#!/bin/bash

# 1. Clone xv6 source code if isn't already there
if [ ! -d "xv6" ]; then
    echo "Cloning xv6 repository..."
    git clone --depth 10 git://g.csail.mit.edu/xv6-labs-2024 xv6
else
    echo "Skipping: xv6 repository already exists."
fi

# 2. Patch the strict C error on line 247
echo "Patching [usertests.c]..."
sed -i '247s/rwsbrk()/rwsbrk(char *s)/' xv6/user/usertests.c

# 3. Create kernel/ptree.h
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

# 4. Append fetchptree() helper to kernel/proc.c
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

# 5. Add fetchptree declaration to kernel/defs.h
if ! grep -q "fetchptree" xv6/kernel/defs.h; then
    if grep -q "procdump" xv6/kernel/defs.h; then
        sed -i '/void[[:space:]]*procdump(void);/a int             fetchptree(uint64, int);' xv6/kernel/defs.h
        echo "  -> Added [fetchptree] to defs.h"
    else
        echo "  !! Warning: procdump not found in defs.h. Add fetchptree declaration manually."
    fi
fi

# 6. Add ptree.h include to user/user.h
if ! grep -q "ptree.h" xv6/user/user.h; then
    sed -i '1i #include "../kernel/ptree.h"' xv6/user/user.h
    echo "  -> Added [#include ptree.h] to user.h"
fi

# 7. Inform the user about the patching process
echo "Patch completed successfully!"
