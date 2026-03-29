#include "kernel/types.h"
#include "kernel/param.h"
#include "kernel/riscv.h"
#include "kernel/ptree.h"
#include "user/user.h"

// ============ TRACE TESTS ============

static void
test_trace(void)
{
  int pid;
  int status;

  printf("--- trace tests ---\n");

  // Test: trace single syscall (read = 5, mask = 32)
  printf("[trace] test 1: trace 32 echo\n");
  pid = fork();
  if (pid == 0) {
    trace(1 << 5); // SYS_read = 5
    char *a[] = {"echo", "tracetest1", 0};
    exec("echo", a);
    exit(1);
  }
  wait(&status);

  // Test: trace all syscalls
  printf("[trace] test 2: trace all for echo\n");
  pid = fork();
  if (pid == 0) {
    trace(2147483647);
    char *a[] = {"echo", "tracetest2", 0};
    exec("echo", a);
    exit(1);
  }
  wait(&status);

  // Test: no trace output with mask=0
  printf("[trace] test 3: mask=0 (no trace expected)\n");
  pid = fork();
  if (pid == 0) {
    trace(0);
    char *a[] = {"echo", "not_traced", 0};
    exec("echo", a);
    exit(1);
  }
  wait(&status);

  // Test: trace fork and verify inheritance
  printf("[trace] test 4: trace fork + inheritance\n");
  trace(1 << 1); // SYS_fork = 1
  pid = fork();
  if (pid == 0) {
    // Child inherits tracemask, this fork should also be traced
    int gc = fork();
    if (gc == 0) exit(0);
    wait(0);
    exit(0);
  }
  wait(&status);
  trace(0); // reset

  // Test: trace with grep (like the assignment example)
  printf("[trace] test 5: trace 32 grep hello README\n");
  pid = fork();
  if (pid == 0) {
    trace(32); // 1 << SYS_read
    char *a[] = {"grep", "hello", "README", 0};
    exec("grep", a);
    exit(1);
  }
  wait(&status);

  printf("[trace] tests done\n");
}

// ============ SYSINFO TESTS ============

static void
test_sysinfo(void)
{
  struct sysinfo info;
  uint64 fm_before, fm_after;

  printf("--- sysinfo tests ---\n");

  // Test: basic call
  printf("[sysinfo] test 1: basic call\n");
  if (sysinfo(&info) < 0) {
    printf("  FAIL: sysinfo returned -1\n");
    return;
  }
  printf("  freemem=%d, nproc=%d\n", (int)info.freemem, (int)info.nproc);
  if (info.freemem > 0)
    printf("  PASS: freemem > 0\n");
  else
    printf("  FAIL: freemem <= 0\n");
  if (info.nproc > 0)
    printf("  PASS: nproc > 0\n");
  else
    printf("  FAIL: nproc <= 0\n");

  // Test: bad pointer
  printf("[sysinfo] test 2: bad pointer\n");
  if (sysinfo((struct sysinfo *)0xdeadbeef) == -1)
    printf("  PASS: returns -1 for bad pointer\n");
  else
    printf("  FAIL: should return -1\n");

  // Test: freemem changes after sbrk
  printf("[sysinfo] test 3: freemem changes\n");
  sysinfo(&info);
  fm_before = info.freemem;

  char *p = sbrk(4096);
  if (p == (char *)-1) {
    printf("  FAIL: sbrk failed\n");
  } else {
    sysinfo(&info);
    fm_after = info.freemem;
    if (fm_before > fm_after)
      printf("  PASS: freemem decreased (before=%d, after=%d)\n", (int)fm_before, (int)fm_after);
    else
      printf("  FAIL: freemem should decrease\n");
    sbrk(-4096);
  }

  // Test: nproc changes after fork
  printf("[sysinfo] test 4: nproc changes with fork\n");
  sysinfo(&info);
  fm_before = info.nproc;

  int cpid = fork();
  if (cpid == 0) {
    sleep(50);
    exit(0);
  }

  sysinfo(&info);
  fm_after = info.nproc;
  if (fm_after >= fm_before + 1)
    printf("  PASS: nproc increased (before=%d, after=%d)\n", (int)fm_before, (int)fm_after);
  else
    printf("  FAIL: nproc should increase\n");

  wait(0);

  printf("[sysinfo] tests done\n");
}

// ============ PTREE TESTS ============

static void
test_ptree(void)
{
  struct ptreeinfo buf[64];
  int res;
  int mypid;
  int found_self = 0;
  int found_child = 0;
  int child_pid;

  printf("--- ptree tests ---\n");

  // Test: basic call
  printf("[ptree] test 1: basic call\n");
  res = ptree(buf, 64);
  if (res > 0)
    printf("  PASS: returned %d processes\n", res);
  else
    printf("  FAIL: returned %d\n", res);

  // Test: self in tree
  printf("[ptree] test 2: self in tree\n");
  mypid = getpid();
  for (int i = 0; i < res; i++) {
    if (buf[i].pid == mypid) {
      found_self = 1;
      printf("  PASS: found self (pid=%d, name=%s, state=%d, mem=%d)\n",
             buf[i].pid, buf[i].name, buf[i].state, (int)buf[i].memsize);
      break;
    }
  }
  if (!found_self)
    printf("  FAIL: self not found\n");

  // Test: forked child appears
  printf("[ptree] test 3: forked child in tree\n");
  child_pid = fork();
  if (child_pid == 0) {
    sleep(200);
    exit(0);
  }

  sleep(10);
  res = ptree(buf, 64);
  for (int i = 0; i < res; i++) {
    if (buf[i].pid == child_pid) {
      found_child = 1;
      if (buf[i].ppid == mypid)
        printf("  PASS: child pid=%d, ppid=%d\n", buf[i].pid, buf[i].ppid);
      else
        printf("  FAIL: child ppid=%d, expected %d\n", buf[i].ppid, mypid);
      break;
    }
  }
  if (!found_child)
    printf("  FAIL: child not found\n");

  kill(child_pid);
  wait(0);

  // Test: error handling
  printf("[ptree] test 4: error handling\n");
  if (ptree(0, 10) == -1)
    printf("  PASS: NULL buf returns -1\n");
  else
    printf("  FAIL: NULL buf should return -1\n");

  if (ptree(buf, 0) == -1)
    printf("  PASS: max=0 returns -1\n");
  else
    printf("  FAIL: max=0 should return -1\n");

  // Test: pstree command works
  printf("[ptree] test 5: running pstree command\n");
  int pid = fork();
  if (pid == 0) {
    char *a[] = {"pstree", 0};
    exec("pstree", a);
    exit(1);
  }
  wait(0);

  printf("[ptree] tests done\n");
}

// ============ MAIN ============

int
main(int argc, char *argv[])
{
  printf("====== ALL TESTS ======\n\n");

  test_trace();
  printf("\n");
  test_sysinfo();
  printf("\n");
  test_ptree();

  printf("\n====== ALL TESTS COMPLETE ======\n");
  exit(0);
}
