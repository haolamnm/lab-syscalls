// PROTOTYPE: int hello(void);

uint64
sys_hello(void)
{
  printf("Hello from kernel!\n");
  return 0;
}
