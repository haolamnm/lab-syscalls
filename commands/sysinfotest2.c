#include "kernel/types.h"
#include "kernel/param.h"
#include "kernel/riscv.h"
#include "user/user.h"

static int tests_passed = 0;
static int tests_failed = 0;

static void
check(int cond, char *msg)
{
  if (cond) {
    printf("  PASS: %s\n", msg);
    tests_passed++;
  } else {
    printf("  FAIL: %s\n", msg);
    tests_failed++;
  }
}

static void
test_basic(void)
{
  struct sysinfo info;

  printf("Test 1: basic sysinfo call\n");
  check(sysinfo(&info) == 0, "sysinfo returns 0");
  check(info.freemem > 0, "freemem > 0");
  check(info.nproc > 0, "nproc > 0");
  printf("  freemem=%d bytes, nproc=%d\n", (int)info.freemem, (int)info.nproc);
}

static void
test_bad_ptr(void)
{
  printf("Test 2: sysinfo with bad pointer\n");
  check(sysinfo((struct sysinfo *)0xdeadbeef) == -1, "sysinfo returns -1 for bad pointer");
  check(sysinfo(0) == -1, "sysinfo returns -1 for NULL");
}

static void
test_freemem_changes(void)
{
  struct sysinfo before, after;
  char *p;

  printf("Test 3: freemem changes with sbrk\n");
  sysinfo(&before);

  p = sbrk(PGSIZE);
  check(p != (char *)-1, "sbrk(PGSIZE) succeeds");

  sysinfo(&after);
  check(after.freemem <= before.freemem, "freemem decreased or same after sbrk");
  check(before.freemem - after.freemem >= PGSIZE, "freemem dropped by at least PGSIZE");

  // Release memory
  check(sbrk(-PGSIZE) != (char *)-1, "sbrk(-PGSIZE) succeeds");

  struct sysinfo after_free;
  sysinfo(&after_free);
  check(after_free.freemem >= after.freemem, "freemem increased after sbrk release");
}

static void
test_nproc_changes(void)
{
  struct sysinfo before, after;
  int pid;

  printf("Test 4: nproc changes with fork/exit\n");
  sysinfo(&before);

  pid = fork();
  if (pid < 0) {
    printf("  FAIL: fork failed\n");
    tests_failed++;
    return;
  }
  if (pid == 0) {
    // Child: sleep briefly then exit
    sleep(50);
    exit(0);
  }

  sysinfo(&after);
  check(after.nproc >= before.nproc + 1, "nproc increased after fork");

  wait(0);

  struct sysinfo after_wait;
  sysinfo(&after_wait);
  check(after_wait.nproc <= after.nproc, "nproc decreased or same after child exits");
}

static void
test_multiple_sbrk(void)
{
  struct sysinfo info1, info2;

  printf("Test 5: multiple sbrk calls\n");
  sysinfo(&info1);

  char *p1 = sbrk(PGSIZE);
  char *p2 = sbrk(PGSIZE);
  char *p3 = sbrk(PGSIZE);
  check(p1 != (char *)-1 && p2 != (char *)-1 && p3 != (char *)-1, "3 sbrk(PGSIZE) succeed");

  sysinfo(&info2);
  check(info1.freemem - info2.freemem >= 3 * PGSIZE, "freemem dropped by at least 3*PGSIZE");

  sbrk(-3 * PGSIZE);
}

int
main(int argc, char *argv[])
{
  printf("=== sysinfo test ===\n");

  test_basic();
  test_bad_ptr();
  test_freemem_changes();
  test_nproc_changes();
  test_multiple_sbrk();

  printf("\n=== Results: %d passed, %d failed ===\n", tests_passed, tests_failed);
  if (tests_failed == 0)
    printf("sysinfotest: ALL OK\n");
  else
    printf("sysinfotest: SOME TESTS FAILED\n");

  exit(0);
}
