#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    // Call the custom system call
    hello();

    printf("Success!\n");
    exit(0);
}
