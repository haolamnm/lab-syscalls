#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/param.h"
#include "kernel/ptree.h"
#include "user/user.h"

#define MAXPROC 64

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
  struct ptreeinfo buf[MAXPROC];
  int res;

  printf("Test 1: basic ptree call\n");
  res = ptree(buf, MAXPROC);
  check(res > 0, "ptree returns > 0");
  check(res <= MAXPROC, "ptree returns <= MAXPROC");
  printf("  ptree returned %d processes\n", res);
}

static void
test_self_in_tree(void)
{
  struct ptreeinfo buf[MAXPROC];
  int res;
  int mypid;
  int found = 0;

  printf("Test 2: current process appears in ptree\n");
  mypid = getpid();
  res = ptree(buf, MAXPROC);
  check(res > 0, "ptree returns > 0");

  for (int i = 0; i < res; i++) {
    if (buf[i].pid == mypid) {
      found = 1;
      check(buf[i].pid == mypid, "found own pid");
      check(buf[i].state > 0, "state is valid");
      check(buf[i].name[0] != 0, "name is non-empty");
      break;
    }
  }
  check(found, "current process found in ptree");
}

static void
test_forked_process(void)
{
  struct ptreeinfo buf[MAXPROC];
  int res;
  int pid;
  int child_found = 0;
  int mypid;

  printf("Test 3: forked child appears in ptree\n");
  mypid = getpid();

  pid = fork();
  if (pid < 0) {
    printf("  FAIL: fork failed\n");
    tests_failed++;
    return;
  }
  if (pid == 0) {
    // Child: sleep so it stays RUNNING/SLEEPING while parent calls ptree
    sleep(200);
    exit(0);
  }

  // Parent: call ptree while child is alive
  res = ptree(buf, MAXPROC);
  check(res > 0, "ptree returns > 0 after fork");

  for (int i = 0; i < res; i++) {
    if (buf[i].pid == pid) {
      child_found = 1;
      check(buf[i].ppid == mypid, "child ppid matches parent pid");
      break;
    }
  }
  check(child_found, "forked child found in ptree");

  wait(0);
}

static void
test_error_cases(void)
{
  struct ptreeinfo buf[MAXPROC];

  printf("Test 4: error handling\n");
  check(ptree(0, 10) == -1, "ptree(NULL, 10) returns -1");
  check(ptree(buf, 0) == -1, "ptree(buf, 0) returns -1");
  check(ptree(buf, -5) == -1, "ptree(buf, -5) returns -1");
}

static void
test_truncation(void)
{
  struct ptreeinfo buf[2];
  int res;

  printf("Test 5: truncation with small buffer\n");
  res = ptree(buf, 2);
  // If there are more than 2 processes, should get truncation sentinel
  // -count - 1 format, or just count if there happen to be <= 2 processes
  check(res != 0, "ptree returns non-zero");
  if (res < -1) {
    printf("  truncation detected: sentinel = %d\n", res);
    check(1, "truncation sentinel returned");
  } else {
    printf("  no truncation (only %d processes)\n", res);
    check(res > 0, "positive count returned");
  }
}

static void
test_grandchild(void)
{
  struct ptreeinfo buf[MAXPROC];
  int res;
  int child_pid;
  int grandchild_found = 0;

  printf("Test 6: grandchild process in ptree\n");

  child_pid = fork();
  if (child_pid < 0) {
    printf("  FAIL: fork failed\n");
    tests_failed++;
    return;
  }
  if (child_pid == 0) {
    // Child: fork a grandchild
    int gc = fork();
    if (gc == 0) {
      // Grandchild: sleep
      sleep(200);
      exit(0);
    }
    // Child: sleep
    sleep(200);
    wait(0);
    exit(0);
  }

  // Parent: wait a bit then check ptree
  sleep(10);
  res = ptree(buf, MAXPROC);
  check(res > 0, "ptree returns > 0 with grandchild");

  // Find the grandchild
  for (int i = 0; i < res; i++) {
    if (buf[i].ppid == child_pid && buf[i].pid != child_pid) {
      grandchild_found = 1;
      check(buf[i].ppid == child_pid, "grandchild ppid matches child pid");
      break;
    }
  }
  check(grandchild_found, "grandchild found in ptree");

  // Clean up
  kill(child_pid);
  wait(0);
}

static void
test_memsize_valid(void)
{
  struct ptreeinfo buf[MAXPROC];
  int res;

  printf("Test 7: memsize values are valid\n");
  res = ptree(buf, MAXPROC);
  check(res > 0, "ptree returns > 0");

  for (int i = 0; i < res; i++) {
    if (buf[i].pid == getpid()) {
      check(buf[i].memsize > 0, "own memsize > 0");
      printf("  pid=%d memsize=%d\n", buf[i].pid, (int)buf[i].memsize);
      break;
    }
  }
}

int
main(int argc, char *argv[])
{
  printf("=== ptree test ===\n");

  test_basic();
  test_self_in_tree();
  test_forked_process();
  test_error_cases();
  test_truncation();
  test_grandchild();
  test_memsize_valid();

  printf("\n=== Results: %d passed, %d failed ===\n", tests_passed, tests_failed);
  if (tests_failed == 0)
    printf("ptreetest: ALL OK\n");
  else
    printf("ptreetest: SOME TESTS FAILED\n");

  exit(0);
}
