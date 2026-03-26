#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/ptree.h"
#include "user/user.h"

#define MAXPROC 64
static struct ptreeinfo procs[MAXPROC];
static int nproc;

// Print indentation: 2 spaces per level
static void
print_indent(int depth)
{
  for (int i = 0; i < depth; i++)
    printf("  ");
}

// Check if a given pid exists in the process list
static int
pid_exists(int pid)
{
  for (int i = 0; i < nproc; i++) {
    if (procs[i].pid == pid)
      return 1;
  }
  return 0;
}

// Recursively print the process tree rooted at process with given pid
static void
print_tree(int pid, int depth)
{
  for (int i = 0; i < nproc; i++) {
    if (procs[i].pid == pid) {
      print_indent(depth);
      // xv6 user printf only supports %d, %x, %s, %p.
      // xv6 process memory is always < 2GB, so (int) cast is safe here.
      printf("%d %s state=%d mem=%d\n",
             procs[i].pid,
             procs[i].name,
             procs[i].state,
             (int)procs[i].memsize);
      break;
    }
  }

  // Find and print all children of this process
  for (int i = 0; i < nproc; i++) {
    if (procs[i].ppid == pid && procs[i].pid != pid) {
      print_tree(procs[i].pid, depth + 1);
    }
  }
}

int
main(int argc, char *argv[])
{
  int res = ptree(procs, MAXPROC);
  if (res < 0) {
    if (res == -1) {
      printf("pstree: ptree syscall failed\n");
      exit(1);
    }
    // Truncated result (sentinel: -count - 1)
    nproc = -res - 1;
    printf("pstree: warning: list truncated, showing %d of more processes\n", nproc);
  } else {
    nproc = res;
  }

  // Find root processes and start the tree from each root.
  // A root process is one that:
  //   - has ppid == 0 (kernel/init-style root), or
  //   - has ppid == pid (self-parented init), or
  //   - has a parent PID that does not appear in the ptree() result
  //     (e.g., when the ptree() buffer is truncated).
  for (int i = 0; i < nproc; i++) {
    if (procs[i].ppid == 0 ||
        procs[i].ppid == procs[i].pid ||
        !pid_exists(procs[i].ppid)) {
      print_tree(procs[i].pid, 0);
    }
  }

  exit(0);
}
