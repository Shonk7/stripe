#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main(void) {
    pid_t pid = fork();

    if (pid < 0) {
        perror("fork");
        return 1;
    }

    if (pid == 0) {
        printf("Child PID: %d\n", getpid());
        fflush(stdout);
        _exit(42);
    }

    printf("Parent PID: %d, Child PID: %d\n", getpid(), pid);
    fflush(stdout);

    sleep(30);

    int status;
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        return 1;
    }

    printf("Child exit code: %d\n", WEXITSTATUS(status));
    return 0;
}
