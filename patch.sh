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

# 3. Inform the user about the patching process
echo "Patch completed successfully!"
