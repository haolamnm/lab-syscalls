// PROTOTYPE: int trace(int);

uint64
sys_trace(void)
{
  int mask;

  argint(0, &mask);
  myproc()->tracemask = mask;
  return 0;
}
