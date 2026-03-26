#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
  int mask;
  char *p;
  if (argc < 3) {
    fprintf(2, "usage: trace mask command [args ...]\n");
    exit(1);
  }
  p = argv[1];
  if (p[0] == '\0') {
    fprintf(2, "usage: trace mask command [args ...]\n");
    exit(1);
  }
  for (; *p; p++) {
    if (*p < '0' || *p > '9') {
      fprintf(2, "usage: trace mask command [args ...]\n");
      exit(1);
    }
  }

  mask = atoi(argv[1]);
  if (trace(mask) < 0) {
    fprintf(2, "trace: trace failed\n");
    exit(1);
  }

  exec(argv[2], &argv[2]);
  fprintf(2, "trace: exec %s failed\n", argv[2]);
  exit(1);
}
