#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/prctl.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* The supervisor stays outside the child's session, reaps descendants and also
 * closes the process group when the Java host dies. stdout starts with a private
 * 8-byte handshake, consumed by the host before any process output is delivered. */
static volatile sig_atomic_t stopped;
static void stop_handler(int value) { (void)value; stopped = 1; }
static long millis(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return now.tv_sec * 1000 + now.tv_nsec / 1000000;
}
static void kill_children(int sig) {
    char path[128];
    snprintf(path, sizeof(path), "/proc/self/task/%d/children", getpid());
    FILE *file = fopen(path, "r");
    if (!file) return;
    int pid;
    while (fscanf(file, "%d", &pid) == 1) kill(pid, sig);
    fclose(file);
}
int main(int argc, char **argv) {
    if (argc < 3) return 125;
    signal(SIGTERM, stop_handler);
    signal(SIGINT, stop_handler);
    signal(SIGPIPE, SIG_IGN);
    prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0);
    pid_t parent = getppid();
    if (prctl(PR_SET_PDEATHSIG, SIGTERM) || getppid() != parent) return 125;
    uint32_t words[] = {0x50484153u, (uint32_t)getpid()};
    if (write(STDOUT_FILENO, words, sizeof(words)) != sizeof(words)) return 125;
    int ready[2];
    if (pipe(ready)) return 125;
    pid_t supervisor = getpid();
    pid_t child = fork();
    if (child < 0) return 125;
    if (child == 0) {
        close(ready[0]);
        signal(SIGTERM, SIG_DFL);
        signal(SIGINT, SIG_DFL);
        if (setsid() < 0) _exit(125);
        prctl(PR_SET_PDEATHSIG, SIGKILL);
        if (getppid() != supervisor) _exit(125);
        char ok = 1;
        if (write(ready[1], &ok, 1) != 1) _exit(125);
        close(ready[1]);
        execv(argv[2], argv + 2);
        _exit(127);
    }
    close(ready[1]);
    char ok;
    if (read(ready[0], &ok, 1) != 1) { kill(child, SIGKILL); waitpid(child, NULL, 0); return 125; }
    close(ready[0]);
    int main_status = 0;
    int main_done = 0;
    long deadline = 0;
    for (;;) {
        int status;
        pid_t pid = waitpid(-1, &status, WNOHANG);
        if (pid > 0) {
            if (pid == child) { main_status = status; main_done = 1; }
            continue;
        }
        if (pid < 0 && errno == ECHILD) break;
        if ((stopped || main_done) && !deadline) {
            kill(-child, SIGTERM);
            kill_children(SIGTERM);
            deadline = millis() + 800;
        }
        if (deadline && millis() >= deadline) {
            kill(-child, SIGKILL);
            kill_children(SIGKILL);
        }
        struct timespec pause = {0, 10000000};
        nanosleep(&pause, NULL);
    }
    FILE *result = fopen(argv[1], "w");
    if (result) {
        fprintf(result, "%d %d\n", WIFEXITED(main_status) ? WEXITSTATUS(main_status) : -1,
                WIFSIGNALED(main_status) ? WTERMSIG(main_status) : 0);
        fclose(result);
    }
    return WIFEXITED(main_status) ? WEXITSTATUS(main_status) : 128 + WTERMSIG(main_status);
}
