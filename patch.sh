#!/bin/bash

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

# 3. Integrate ptree-specific kernel modifications
echo "Applying [ptree] kernel patches..."

# 3a. Chép file header ptree.h vào kernel
if [ -f "kernel/ptree.h" ]; then
    cp kernel/ptree.h xv6/kernel/ptree.h
    echo "  -> Copied [ptree.h] to xv6/kernel/"
fi

# 3b. Nối hàm helper vào proc.c
if [ -f "kernel/proc_ptree.c" ] && ! grep -q "fetchptree" xv6/kernel/proc.c; then
    echo "" >> xv6/kernel/proc.c
    cat kernel/proc_ptree.c >> xv6/kernel/proc.c
    echo "  -> Appended helper to [proc.c]"
fi

# 3c. Thêm khai báo vào defs.h
if ! grep -q "fetchptree" xv6/kernel/defs.h; then
    sed -i '/void[[:space:]]*procdump(void);/a int             fetchptree(uint64, int);' xv6/kernel/defs.h
    echo "  -> Added [fetchptree] to defs.h"
fi

# 3d. Thêm forward declaration vào user.h
if ! grep -q "struct ptreeinfo;" xv6/user/user.h; then
    sed -i '1i struct ptreeinfo;' xv6/user/user.h
    echo "  -> Added [struct ptreeinfo] to user.h"
fi

# 4. Inform the user about the patching process
echo "Patch completed successfully!"
