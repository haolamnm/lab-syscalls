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

// Recursively print the process tree rooted at process with given pid
static void
print_tree(int pid, int depth)
{
  for (int i = 0; i < nproc; i++) {
    if (procs[i].pid == pid) {
      print_indent(depth);
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
  nproc = ptree(procs, MAXPROC);
  if (nproc < 0) {
    printf("pstree: ptree syscall failed\n");
    exit(1);
  }

  // Find root processes (ppid == 0 or ppid == self, i.e., init)
  // and start the tree from each root
  for (int i = 0; i < nproc; i++) {
    // A root process has no parent in our list, or is its own parent
    if (procs[i].ppid == 0 || procs[i].ppid == procs[i].pid) {
      print_tree(procs[i].pid, 0);
    }
  }

  exit(0);
}
