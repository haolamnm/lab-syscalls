#ifndef _PTREE_H_
#define _PTREE_H_

struct ptreeinfo {
    int pid;          // Process ID
    int ppid;         // Parent Process ID
    int state;        // Process State
    uint64 memsize;   // User memory size in bytes
    char name[16];    // Process Name
};

#endif
