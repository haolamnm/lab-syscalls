// This code will be appended to kernel/proc.c by integrate.sh
// fetchptree: collect info about all active processes
// Returns number of processes written, or -1 on error.

#include "ptree.h"

int
fetchptree(uint64 buf, int max)
{
  struct proc *p;
  struct ptreeinfo info;
  struct proc *caller = myproc();
  int count = 0;

  for (p = proc; p < &proc[NPROC]; p++) {
    if (count >= max)
      break;

    acquire(&p->lock);
    if (p->state != UNUSED) {
      info.pid = p->pid;
      info.ppid = (p->parent) ? p->parent->pid : 0;
      info.state = p->state;
      info.memsize = p->sz;
      safestrcpy(info.name, p->name, sizeof(info.name));
      release(&p->lock);

      // Copy this entry to user space using the calling process's page table
      if (copyout(caller->pagetable, buf + count * sizeof(struct ptreeinfo),
                  (char *)&info, sizeof(struct ptreeinfo)) < 0) {
        return -1;
      }
      count++;
    } else {
      release(&p->lock);
    }
  }

  return count;
}
