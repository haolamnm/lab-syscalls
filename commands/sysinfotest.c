#include "kernel/types.h"
#include "kernel/param.h"
#include "kernel/riscv.h"
#include "user/user.h"

void
sinfo(struct sysinfo *info)
{
  if(sysinfo(info) < 0){
    printf("FAIL: sysinfo failed\n");
    exit(1);
  }
}

void
testcall(void)
{
  struct sysinfo info;

  if(sysinfo(&info) < 0){
    printf("FAIL: sysinfo failed\n");
    exit(1);
  }

  if(sysinfo((struct sysinfo*)0xeaeb0b5b00002f5e) != -1){
    printf("FAIL: sysinfo succeeded with bad argument\n");
    exit(1);
  }
}

void
testmem(void)
{
  struct sysinfo info;
  uint64 n;
  char *p;

  sinfo(&info);
  n = info.freemem;

  p = sbrk(PGSIZE);
  if(p == (char*)-1){
    printf("FAIL: sbrk failed\n");
    exit(1);
  }

  sinfo(&info);
  if(n < info.freemem || n - info.freemem < PGSIZE){
    printf("FAIL: wrong freemem\n");
    exit(1);
  }

  if(sbrk(-PGSIZE) == (char*)-1){
    printf("FAIL: sbrk failed\n");
    exit(1);
  }
}

void
testproc(void)
{
  struct sysinfo info;
  uint64 n;
  int pid;

  sinfo(&info);
  n = info.nproc;

  pid = fork();
  if(pid < 0){
    printf("FAIL: fork failed\n");
    exit(1);
  }
  if(pid == 0){
    sleep(200);
    exit(0);
  }

  sinfo(&info);
  if(info.nproc < n + 1){
    printf("FAIL: wrong nproc\n");
    kill(pid);
    wait(0);
    exit(1);
  }

  wait(0);
}

int
main(int argc, char *argv[])
{
  testcall();
  testmem();
  testproc();
  printf("sysinfotest: OK\n");
  exit(0);
}
