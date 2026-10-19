#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main(void) {
    printf("Parent PID: %d\n", getpid());
    fflush(stdout);
    pid_t pid = fork();

    if (pid < 0) {
        perror("fork");
        return 1;
    }

    if (pid == 0) {
        printf("child PID %d, parent PID %d\n", getpid(), getppid()); 
        execlp("sleep", "sleep", "30", (char *)NULL);

        perror("execlp failed");
        _exit(127)
    }

    printf("child PID %d\n", pid); 
    int status; 
    if ( waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        return 1;
    }

    if (WIFEXITED(status)) {
        printf("Child exited with code %d\n", WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        printf("Child killed by signal %d\n", WTERMSIG(status));
    }
    return 0;
}
