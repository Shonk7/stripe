#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s sleep|cpu\n", argv[0]);
        return 1;
    }

    printf("PID: %d\n", getpid());
    fflush(stdout);

    if (strcmp(argv[1], "sleep") == 0) {
        while (1) {
            sleep(1);
        }
    } else if (strcmp(argv[1], "cpu") == 0) {
        volatile unsigned long counter = 0;
        while (1) {
            counter++;
        }
    } else {
        fprintf(stderr, "Unknown mode\n");
        return 1;
    }
}
