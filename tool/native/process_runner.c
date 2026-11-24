#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* The supervisor stays outside the child's session and reaps descendants.
 * Ubuntu consumes an 8-byte handshake before normal stdout. The Root host
 * uses stdout for the handshake and exit report, with command output on stderr. */
static volatile sig_atomic_t stopped;
static void stop_handler(int value) { (void)value; stopped = 1; }
static const long root_timeout_ms = 60000;
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
    int root = strcmp(argv[1], "--controlled-root") == 0;
    if (root && (getuid() != 0 || geteuid() != 0)) return 126;
    signal(SIGTERM, stop_handler);
    signal(SIGINT, stop_handler);
    signal(SIGPIPE, SIG_IGN);
    if (prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) && root) return 125;
    pid_t parent = getppid();
    if (prctl(PR_SET_PDEATHSIG, SIGTERM) || getppid() != parent) return 125;
    struct pollfd control = { .fd = STDIN_FILENO, .events = POLLIN };
    long root_deadline = 0;
    if (root) {
        // Only start after the app receives the verified root handshake.
        const char ready[] = "PHASROOT\n";
        if (write(STDOUT_FILENO, ready, sizeof(ready) - 1) != sizeof(ready) - 1) return 125;
        char start;
        if (poll(&control, 1, root_timeout_ms) <= 0 || stopped ||
            read(STDIN_FILENO, &start, 1) != 1 || start != '1') return 125;
        root_deadline = millis() + root_timeout_ms;
    } else {
        uint32_t words[] = {0x50484153u, (uint32_t)getpid()};
        if (write(STDOUT_FILENO, words, sizeof(words)) != sizeof(words)) return 125;
    }
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
        if (root) {
            signal(SIGPIPE, SIG_DFL);
            int input = open("/dev/null", O_RDONLY);
            if (input < 0 || dup2(input, STDIN_FILENO) < 0 ||
                dup2(STDERR_FILENO, STDOUT_FILENO) < 0) _exit(125);
            if (input != STDIN_FILENO) close(input);
        }
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
    int root_timed_out = 0;
    long deadline = 0;
    for (;;) {
        int status;
        pid_t pid = waitpid(-1, &status, WNOHANG);
        if (pid > 0) {
            if (pid == child) { main_status = status; main_done = 1; }
            continue;
        }
        if (pid < 0 && errno == ECHILD) break;
        if (root && !deadline) {
            root_timed_out = millis() >= root_deadline;
            if (root_timed_out || poll(&control, 1, 0) > 0) stopped = 1;
        }
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
    int exit_code = WIFEXITED(main_status) ? WEXITSTATUS(main_status) : 128 + WTERMSIG(main_status);
    if (root) {
        if (root_timed_out) {
            dprintf(STDOUT_FILENO, "TIMEOUT\n");
            return 124;
        }
        dprintf(STDOUT_FILENO, "EXIT:%d\n", exit_code);
        return exit_code;
    }
    FILE *result = fopen(argv[1], "w");
    if (result) {
        fprintf(result, "%d %d\n", WIFEXITED(main_status) ? WEXITSTATUS(main_status) : -1,
                WIFSIGNALED(main_status) ? WTERMSIG(main_status) : 0);
        fclose(result);
    }
    return exit_code;
}
