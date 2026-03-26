// PROTOTYPE: int ptree(struct ptreeinfo *buf, int max);

#include "ptree.h"

uint64
sys_ptree(void)
{
  uint64 buf;    // user-space pointer
  int max;

  // Extract arguments from trapframe
  argaddr(0, &buf);
  argint(1, &max);

  // Validate arguments
  if (max <= 0)
    return -1;

  // Call the helper function in proc.c
  return fetchptree(buf, max);
}
