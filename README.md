# XV6 syscalls

## 1. Setup

Before doing anything, pull down the xv6 source code and apply the base patches.

```bash
chmod +x ./patch.sh
./patch.sh
```

## 2. Add commands (user-space)

How to add a command:
1. Create a `.c` file inside the `commands/` folder.
2. Write your standard user-space C code with an `int main()` function.
3. The script will automatically link it to `xv6/user/` and register it in the `Makefile` under `UPROGS` entry.

Example: [`commands/hello.c`](commands/hello.c)

## 3. Add syscalls (kernel-space)

The integration script handles all the tedious wiring (`usys.pl`, `syscall.h`, `syscall.c`, etc.) for you.

How to add a syscall:
1. Create a `.c` file inside the `syscalls/` folder.
2. IMPORTANT: The very first line of your file must be a comment starting with `// PROTOTYPE:`. The script parses this line to correctly declare the function for user-space programs in `user/user.h`.
3. Write your kernel implementation function naming it sys_[filename] (e.g. `sys_hello`).

Example: [`syscalls/hello.c`](syscalls/hello.c)

Note: The script will auto-assign the next available `SYS_` magic number starting from 22.

## 4. Workflow

We have a wrapper script called [`run.sh`](run.sh) to compile and boot QEMU safely, which automatically invoke [`integrate.sh`](integrate.sh) under the hood.

Dev loop:
1. Write code in `commands/` or `syscalls/`.
2. Run `./run.sh fresh`.
3. Inside the QEMU terminal, type the name of your command to test it!
