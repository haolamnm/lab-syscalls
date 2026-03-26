#!/bin/bash

set -e

# 1. Clone xv6 source code if isn't already there
if [ ! -d "xv6" ]; then
    echo "Cloning xv6 repository..."
    git clone --depth 10 git://g.csail.mit.edu/xv6-labs-2024 xv6
else
    echo "Skipping: xv6 repository already exists."
fi

# 2. Patch the strict C error on line 247
echo "Patching [usertests.c]..."
sed -i '247s/rwsbrk()/rwsbrk(char *s)/' xv6/user/usertests.c

# 3. Inject tracemask into proc structure for trace syscall
echo "Patching [proc.h] for tracemask..."
if ! grep -q "int tracemask;" xv6/kernel/proc.h; then
    sed -i '/char name\[16\]/i\  int tracemask;            // Syscall trace bitmask' xv6/kernel/proc.h
    echo "  -> Added tracemask field to struct proc."
else
    echo "  -> tracemask already exists. Skipping."
fi

# 4. Patch proc.c tracemask lifecycle behavior
echo "Patching [proc.c] tracemask lifecycle..."
if ! awk '/p->state = USED;/{getline; if($0 ~ /p->tracemask = 0;/) found=1} END{exit found?0:1}' xv6/kernel/proc.c; then
    sed -i '/p->state = USED;/a\  p->tracemask = 0;' xv6/kernel/proc.c
    echo "  -> Added tracemask init in allocproc()."
else
    echo "  -> allocproc() tracemask init already exists. Skipping."
fi

if ! awk '/safestrcpy\(np->name, p->name, sizeof\(p->name\)\);/{getline; if($0 ~ /np->tracemask = p->tracemask;/) found=1} END{exit found?0:1}' xv6/kernel/proc.c; then
    sed -i '/safestrcpy(np->name, p->name, sizeof(p->name));/a\  np->tracemask = p->tracemask;' xv6/kernel/proc.c
    echo "  -> Added tracemask inheritance in fork()."
else
    echo "  -> fork() tracemask inheritance already exists. Skipping."
fi

if ! awk '/p->xstate = 0;/{getline; if($0 ~ /p->tracemask = 0;/) found=1} END{exit found?0:1}' xv6/kernel/proc.c; then
    sed -i '/p->xstate = 0;/a\  p->tracemask = 0;' xv6/kernel/proc.c
    echo "  -> Added tracemask reset in freeproc()."
else
    echo "  -> freeproc() tracemask reset already exists. Skipping."
fi

# 5. Patch integrate.sh to make syscall reinjection idempotent
echo "Patching [integrate.sh] marker deletion..."
if ! grep -Fq 'grep -Fq "$START_MARKER" xv6/kernel/sysproc.c' integrate.sh; then
    sed -i 's#if grep -q "\$START_MARKER" xv6/kernel/sysproc.c; then#if grep -Fq "\$START_MARKER" xv6/kernel/sysproc.c; then#' integrate.sh
fi

if ! grep -Fq 'sed -i "\|$START_MARKER|,\|$END_MARKER|d" xv6/kernel/sysproc.c' integrate.sh; then
    sed -i 's#sed -i "/\$START_MARKER/,/\$END_MARKER/d" xv6/kernel/sysproc.c#sed -i "\\|$START_MARKER|,\\|$END_MARKER|d" xv6/kernel/sysproc.c#' integrate.sh
fi
echo "  -> Updated marker match and deletion delimiters."

# 6. Integrate custom syscalls/commands into freshly cloned xv6
echo "Running integration step..."
bash ./integrate.sh

# 7. Patch syscall.c to print traced syscall output
echo "Patching [syscall.c] trace output logic..."
if ! grep -q 'static char \*syscall_names\[\]' xv6/kernel/syscall.c; then
    awk '
        BEGIN { in_syscalls = 0; inserted = 0 }
        /static uint64 \(\*syscalls\[\]\)\(void\) = \{/ { in_syscalls = 1 }
        {
            print
            if (in_syscalls && $0 ~ /^};$/ && !inserted) {
                print ""
                print "static char *syscall_names[] = {"
                print "[SYS_fork]    \"fork\"," 
                print "[SYS_exit]    \"exit\"," 
                print "[SYS_wait]    \"wait\"," 
                print "[SYS_pipe]    \"pipe\"," 
                print "[SYS_read]    \"read\"," 
                print "[SYS_kill]    \"kill\"," 
                print "[SYS_exec]    \"exec\"," 
                print "[SYS_fstat]   \"fstat\"," 
                print "[SYS_chdir]   \"chdir\"," 
                print "[SYS_dup]     \"dup\"," 
                print "[SYS_getpid]  \"getpid\"," 
                print "[SYS_sbrk]    \"sbrk\"," 
                print "[SYS_sleep]   \"sleep\"," 
                print "[SYS_uptime]  \"uptime\"," 
                print "[SYS_open]    \"open\"," 
                print "[SYS_write]   \"write\"," 
                print "[SYS_mknod]   \"mknod\"," 
                print "[SYS_unlink]  \"unlink\"," 
                print "[SYS_link]    \"link\"," 
                print "[SYS_mkdir]   \"mkdir\"," 
                print "[SYS_close]   \"close\"," 
                print "[SYS_trace]   \"trace\"," 
                print "[SYS_hello]   \"hello\"," 
                print "};"
                inserted = 1
                in_syscalls = 0
            }
        }
    ' xv6/kernel/syscall.c > xv6/kernel/syscall.c.tmp
    mv xv6/kernel/syscall.c.tmp xv6/kernel/syscall.c
    echo "  -> Added syscall_names[] table."
else
    echo "  -> syscall_names[] table already exists. Skipping."
fi

# Remove malformed function-pointer entries accidentally placed in syscall_names[]
awk '
    /static char \*syscall_names\[\] = \{/ { in_names = 1 }
    in_names && /\[SYS_trace\][[:space:]]*sys_trace,/ { next }
    in_names && /\[SYS_hello\][[:space:]]*sys_hello,/ { next }
    in_names && /^};$/ { in_names = 0 }
    { print }
' xv6/kernel/syscall.c > xv6/kernel/syscall.c.tmp
mv xv6/kernel/syscall.c.tmp xv6/kernel/syscall.c

if ! grep -q 'p->tracemask >> num' xv6/kernel/syscall.c; then
    sed -i '/p->trapframe->a0 = syscalls\[num\]();/a\
\
    if(((p->tracemask >> num) \& 1) && num < NELEM(syscall_names) && syscall_names[num])\
      printf("%d: syscall %s -> %d\\n", p->pid, syscall_names[num], (int)p->trapframe->a0);' xv6/kernel/syscall.c
    echo "  -> Added trace print hook in syscall()."
else
    echo "  -> Trace print hook already exists. Skipping."
fi

# 8. Inform the user about the patching process
echo "Patch completed successfully!"
