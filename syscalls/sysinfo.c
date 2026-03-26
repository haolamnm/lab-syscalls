// PROTOTYPE: int sysinfo(struct sysinfo *);

uint64
sys_sysinfo(void)
{
  uint64 addr;
  struct sysinfo info;

  argaddr(0, &addr);
  info.freemem = freemem();
  info.nproc = nproc();

  if(copyout(myproc()->pagetable, addr, (char *)&info, sizeof(info)) < 0)
    return -1;
  return 0;
}
