#include "kernel/types.h"
#include "kernel/param.h"
#include "user/user.h"

#define SYS_read   5
#define SYS_write  16
#define SYS_fork   1
#define SYS_exec   7

int
main(int argc, char *argv[])
{
  int pid;
  int status;

  printf("=== trace test ===\n");

  // Test 1: trace read (mask = 1 << SYS_read = 32)
  // Should print trace lines for each read syscall
  printf("Test 1: trace 32 echo hello (tracing read)\n");
  pid = fork();
  if (pid < 0) {
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if (pid == 0) {
    trace(1 << SYS_read);
    char *args[] = {"echo", "hello", 0};
    exec("echo", args);
    printf("FAIL: exec echo failed\n");
    exit(1);
  }
  wait(&status);

  // Test 2: trace all syscalls (mask = 2147483647)
  printf("Test 2: trace all for echo hello\n");
  pid = fork();
  if (pid < 0) {
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if (pid == 0) {
    trace(2147483647);
    char *args[] = {"echo", "hello", 0};
    exec("echo", args);
    printf("FAIL: exec echo failed\n");
    exit(1);
  }
  wait(&status);

  // Test 3: no trace when mask = 0
  printf("Test 3: no trace output expected\n");
  pid = fork();
  if (pid < 0) {
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if (pid == 0) {
    trace(0);
    char *args[] = {"echo", "silent", 0};
    exec("echo", args);
    printf("FAIL: exec echo failed\n");
    exit(1);
  }
  wait(&status);
  printf("(should see 'silent' above but no syscall trace lines)\n");

  // Test 4: trace fork (mask = 1 << SYS_fork = 2)
  printf("Test 4: trace fork\n");
  pid = fork();
  if (pid < 0) {
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if (pid == 0) {
    trace(1 << SYS_fork);
    // fork a child, the fork syscall should be traced
    int cpid = fork();
    if (cpid == 0) {
      exit(0);
    }
    wait(0);
    exit(0);
  }
  wait(&status);

  // Test 5: trace inheritance - child inherits tracemask
  printf("Test 5: trace inheritance across fork\n");
  trace(1 << SYS_fork);
  pid = fork();
  if (pid < 0) {
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if (pid == 0) {
    // Child: fork again, should also be traced
    int grandchild = fork();
    if (grandchild == 0) {
      exit(0);
    }
    wait(0);
    exit(0);
  }
  wait(&status);
  // Reset tracemask
  trace(0);

  // Test 6: trace write (mask = 1 << SYS_write = 65536)
  printf("Test 6: trace write\n");
  pid = fork();
  if (pid < 0) {
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if (pid == 0) {
    trace(1 << SYS_write);
    char *args[] = {"echo", "traced_write", 0};
    exec("echo", args);
    printf("FAIL: exec echo failed\n");
    exit(1);
  }
  wait(&status);

  printf("=== trace test: ALL DONE ===\n");
  exit(0);
}
