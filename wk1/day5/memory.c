#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>

#define SIZE (256UL * 1024 * 1024)

int main(void) {
    printf("PID: %d\n", getpid());

    char* mp = mmap(NULL, SIZE, PROT_READ | PROT_WRITE,  MAP_PRIVATE | MAP_ANONYMOUS,
        -1, 0);

    if (mp == (int *) -1) {
        perror("mmap error");
        _exit(1);
    }
    

    printf("Memory reserved. Press Enter to continue.\n");
    getchar();

    long page_size = sysconf(_SC_PAGESIZE);
    for (size_t offset = 0; offset < SIZE; offset += page_size) {
        mp[offset] = 0x41;
    }

    printf("Memory touched. Press Enter to exit.\n");
    getchar();

    // TODO 4: Release the mapping using munmap()
    if (munmap(mp, SIZE) == -1) {
        perror("munmap");
        return 1;
    }   
    return 0;
}
