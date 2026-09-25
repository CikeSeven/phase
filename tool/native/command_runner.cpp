// phase's single-command supervisor and bounded transfer endpoint. No Agent
// state.
#include <algorithm>
#include <arpa/inet.h>
#include <array>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <netinet/in.h>
#include <poll.h>
#include <stdexcept>
#include <string>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

#include "command_common.h"
#include "command_transfer.h"
volatile sig_atomic_t stopping;
static void stop_signal(int) { stopping = 1; }
static int64_t now_ms() {
  timespec t{};
  clock_gettime(CLOCK_BOOTTIME, &t);
  return int64_t(t.tv_sec) * 1000 + t.tv_nsec / 1000000;
}
static string quote(const string &s) {
  string out = "\"";
  const char *hex = "0123456789abcdef";
  for (unsigned char c : s) {
    if (c == '"' || c == '\\') {
      out += '\\';
      out += char(c);
    } else if (c < 32) {
      out += "\\u00";
      out += hex[c >> 4];
      out += hex[c & 15];
    } else
      out += char(c);
  }
  return out + '"';
}
static string read_file(const string &path, size_t limit = 131072) {
  Fd f(open(path.c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC));
  require(f.n >= 0, "fileUnavailable");
  string result;
  char bytes[4096];
  ssize_t n;
  while ((n = read(f.n, bytes, sizeof(bytes))) > 0) {
    require(result.size() + size_t(n) <= limit, "fileTooLarge");
    result.append(bytes, size_t(n));
  }
  require(n == 0, "readFailed");
  return result;
}
static void atomic_file(const string &path, const string &text) {
  string temp = path + "." + std::to_string(getpid()) + ".tmp";
  Fd f(open(temp.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            0600));
  require(f.n >= 0, "writeFailed");
  try {
    write_all(f.n, text.data(), text.size());
    require(fsync(f.n) == 0 && rename(temp.c_str(), path.c_str()) == 0,
            "writeFailed");
  } catch (...) {
    unlink(temp.c_str());
    throw;
  }
}
static void directory(const string &p) {
  if (mkdir(p.c_str(), 0700) != 0)
    require(errno == EEXIST, "directoryFailed");
  struct stat s{};
  require(lstat(p.c_str(), &s) == 0 && S_ISDIR(s.st_mode) &&
              s.st_uid == getuid(),
          "invalidDirectory");
}
static bool id_ok(const string &s) {
  return !s.empty() && s.size() <= 100 &&
         std::all_of(s.begin(), s.end(), [](char c) {
           return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                  (c >= '0' && c <= '9') || c == '-' || c == '_';
         });
}
static string job_path(char **v) {
  require(id_ok(v[3]) && string(v[4]).size() == 64, "invalidIdentity");
  return string(v[2]) + "/" + v[3];
}
static void authenticate(const string &job, const string &token) {
  require(read_file(job + "/token", 64) == token, "invalidIdentity");
}
static string base64(const string &s) {
  const char *table =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  string out;
  uint32_t b = 0;
  int bits = 0;
  for (unsigned char c : s) {
    b = (b << 8) | c;
    bits += 8;
    while (bits >= 6) {
      bits -= 6;
      out += table[(b >> bits) & 63];
    }
  }
  if (bits)
    out += table[(b << (6 - bits)) & 63];
  while (out.size() % 4)
    out += '=';
  return out;
}
static string page(const string &path, int64_t offset, size_t maximum) {
  require(offset >= 0, "invalidOffset");
  Fd f(open(path.c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC));
  if (f.n < 0) {
    require(errno == ENOENT && offset == 0, "logUnavailable");
    return "";
  }
  struct stat s{};
  require(fstat(f.n, &s) == 0 && offset <= s.st_size, "invalidOffset");
  string bytes(maximum, '\0');
  ssize_t n = pread(f.n, bytes.data(), maximum, offset);
  require(n >= 0, "logUnavailable");
  bytes.resize(size_t(n));
  return bytes;
}
static std::vector<pid_t> children() {
  std::ifstream file("/proc/self/task/" + std::to_string(getpid()) +
                     "/children");
  require(file.good(), "childrenUnavailable");
  std::vector<pid_t> pids;
  pid_t p;
  while (file >> p)
    pids.push_back(p);
  return pids;
}
static void signal_children(pid_t leader, int signal) {
  kill(-leader, signal);
  for (pid_t pid : children())
    kill(pid, signal); // Only unreaped children owned by this supervisor.
}
static string result_json(int code, int signal, bool cancelled, bool limited,
                          bool acknowledged, const string &error) {
  return "{\"version\":1,\"state\":\"exited\",\"exitCode\":" +
         (code < 0 ? "null" : std::to_string(code)) +
         ",\"signal\":" + (signal == 0 ? "null" : std::to_string(signal)) +
         ",\"cancelled\":" + (cancelled ? "true" : "false") +
         ",\"outputLimitExceeded\":" + (limited ? "true" : "false") +
         ",\"terminationAcknowledged\":" + (acknowledged ? "true" : "false") +
         ",\"error\":" + (error.empty() ? "null" : quote(error)) + "}";
}
static int run_job(const string &job) {
  Fd once(open((job + "/started").c_str(),
               O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0600));
  require(once.n >= 0, "alreadyDispatched");
  string error;
  bool cancelled = false, limited = false;
  int status = 0;
  pid_t child = -1;
  bool reaped = false;
  int out[2]{-1, -1}, err[2]{-1, -1};
  try {
    require(prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) == 0,
            "subreaperUnavailable");
    // Java/Termux may retire the thread that spawned us while their process
    // remains alive. The host lease owns this supervisor's lifetime; attaching
    // PDEATHSIG to that transient thread would spuriously stop long commands.
    // The command child below still tracks this single-threaded supervisor.
    require(!exists(job + "/cancel") &&
                std::stoll(read_file(job + "/lease")) > now_ms(),
            "cancelled");
    string command = read_file(job + "/command"), cwd = read_file(job + "/cwd"),
           shell = read_file(job + "/shell"), home = read_file(job + "/home"),
           path = read_file(job + "/path");
    std::vector<string> helper_args;
    if (exists(job + "/workspaceArgs")) {
      string encoded = read_file(job + "/workspaceArgs");
      size_t start = 0;
      while (start < encoded.size()) {
        size_t end = encoded.find('\0', start);
        require(end != string::npos, "invalidArguments");
        helper_args.push_back(encoded.substr(start, end - start));
        start = end + 1;
      }
      require(helper_args.size() == 9 && helper_args[0] == "workspace", "invalidArguments");
    }
    int64_t limit = std::stoll(read_file(job + "/limit"));
    require(limit > 0 && limit <= 64 * 1024 * 1024, "invalidLimit");
    Fd stdout_log(open((job + "/stdout").c_str(),
                       O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600));
    Fd stderr_log(open((job + "/stderr").c_str(),
                       O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600));
    require(stdout_log.n >= 0 && stderr_log.n >= 0 &&
                pipe2(out, O_CLOEXEC) == 0 && pipe2(err, O_CLOEXEC) == 0,
            "pipeFailed");
    pid_t supervisor = getpid();
    child = fork();
    require(child >= 0, "forkFailed");
    if (child == 0) {
      signal(SIGTERM, SIG_DFL);
      signal(SIGINT, SIG_DFL);
      signal(SIGPIPE, SIG_DFL);
      if (setsid() < 0 || prctl(PR_SET_PDEATHSIG, SIGKILL) != 0 ||
          getppid() != supervisor)
        _exit(125);
      int input = open("/dev/null", O_RDONLY);
      if (input < 0 || dup2(input, 0) < 0 || dup2(out[1], 1) < 0 ||
          dup2(err[1], 2) < 0)
        _exit(125);
      close(input);
      close(out[0]);
      close(out[1]);
      close(err[0]);
      close(err[1]);
      clearenv();
      setenv("HOME", home.c_str(), 1);
      setenv("PATH", path.c_str(), 1);
      setenv("LANG", "C.UTF-8", 1);
      if (shell.find("com.termux") != string::npos) {
        string prefix = "/data/data/com.termux/files/usr";
        setenv("PREFIX", prefix.c_str(), 1);
        setenv("TMPDIR", (prefix + "/tmp").c_str(), 1);
      }
      if (chdir(cwd.c_str()) != 0) {
        dprintf(2, "Cannot enter working directory: %s\n", strerror(errno));
        _exit(125);
      }
      if (!helper_args.empty()) {
        std::vector<char *> argv{const_cast<char *>(shell.c_str())};
        for (auto &arg : helper_args) argv.push_back(const_cast<char *>(arg.c_str()));
        argv.push_back(nullptr);
        execv(shell.c_str(), argv.data());
      } else if (shell.find("bash") != string::npos)
        execl(shell.c_str(), shell.c_str(), "--noprofile", "--norc", "-c",
              command.c_str(), (char *)nullptr);
      else
        execl(shell.c_str(), shell.c_str(), "-c", command.c_str(),
              (char *)nullptr);
      _exit(127);
    }
    close(out[1]);
    out[1] = -1;
    close(err[1]);
    err[1] = -1;
    int64_t received = 0, deadline = 0;
    bool main_done = false;
    while (true) {
      siginfo_t info{};
      require(waitid(P_PID, child, &info, WEXITED | WNOHANG | WNOWAIT) == 0,
              "waitFailed");
      main_done = info.si_pid == child;
      cancelled = cancelled || stopping || exists(job + "/cancel");
      if (std::stoll(read_file(job + "/lease")) < now_ms()) {
        cancelled = true;
        error = "leaseExpired";
      }
      if ((main_done || cancelled || limited) && deadline == 0) {
        signal_children(child, SIGTERM);
        deadline = now_ms() + 800;
      }
      if (deadline && now_ms() >= deadline)
        signal_children(child, SIGKILL);
      auto owned = children();
      for (pid_t pid : owned)
        if (pid != child) {
          int ignored;
          waitpid(pid, &ignored, WNOHANG);
        }
      pollfd fds[2]{{out[0], POLLIN, 0}, {err[0], POLLIN, 0}};
      poll(fds, 2, 20);
      for (int i = 0; i < 2; i++) {
        int &fd = i == 0 ? out[0] : err[0];
        if (fd < 0 || !fds[i].revents)
          continue;
        char bytes[16384];
        ssize_t n = read(fd, bytes, sizeof(bytes));
        if (n == 0) {
          close(fd);
          fd = -1;
        } else if (n > 0) {
          size_t accepted = size_t(
              std::min<int64_t>(n, std::max<int64_t>(0, limit - received)));
          // Do not use cancellation-aware write_all: retain output already
          // received on stop.
          size_t done = 0;
          while (done < accepted) {
            ssize_t w = write(i == 0 ? stdout_log.n : stderr_log.n,
                              bytes + done, accepted - done);
            require(w > 0, "logWriteFailed");
            done += size_t(w);
          }
          received += int64_t(accepted);
          if (received >= limit)
            limited = true;
        } else if (errno != EINTR)
          throw std::runtime_error("outputReadFailed");
      }
      if (main_done && children().size() == 1 && out[0] < 0 && err[0] < 0) {
        require(waitpid(child, &status, 0) == child, "waitFailed");
        reaped = true;
        break;
      }
    }
  } catch (const std::exception &e) {
    error = e.what();
    cancelled = cancelled || stopping || error == "cancelled";
    if (child > 0 && !reaped) {
      // Keep the leader unreaped on the failure path too: its numeric PGID must
      // never be used after waitpid has released it for reuse.
      try {
        for (;;) {
          siginfo_t info{};
          require(waitid(P_PID, child, &info, WEXITED | WNOHANG | WNOWAIT) == 0,
                  "waitFailed");
          signal_children(child, SIGKILL);
          for (pid_t pid : children()) {
            if (pid != child) {
              int ignored;
              waitpid(pid, &ignored, WNOHANG);
            }
          }
          if (info.si_pid == child && children().size() == 1) {
            reaped = waitpid(child, &status, 0) == child;
            break;
          }
          timespec pause{0, 10000000};
          nanosleep(&pause, nullptr);
        }
      } catch (...) {
        error = "cleanupIncomplete";
      }
    }
  }
  for (int fd : {out[0], out[1], err[0], err[1]})
    if (fd >= 0)
      close(fd);
  // Persist terminal facts even after SIGTERM; cancellation does not fabricate
  // exit 143.
  stopping = 0;
  string result =
      result_json(reaped && WIFEXITED(status) ? WEXITSTATUS(status) : -1,
                  reaped && WIFSIGNALED(status) ? WTERMSIG(status) : 0,
                  cancelled, limited, child < 0 || reaped, error);
  atomic_file(job + "/result", result);
  std::cout << result;
  return 0;
}

#include "workspace_files.h"

int main(int argc, char **v) {
  signal(SIGTERM, stop_signal);
  signal(SIGINT, stop_signal);
  signal(SIGPIPE, SIG_IGN);
  try {
    require(argc >= 2, "invalidArguments");
    string op = v[1];
    if (op == "workspace") {
      std::cout << workspace_operation(argc, v);
      return 0;
    }
    if (op == "probe") {
      require(prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) == 0,
              "subreaperUnavailable");
      children();
      std::cout << "{\"version\":1,\"uid\":" << getuid() << "}";
      return 0;
    }
    if (op == "transfer") {
      require(argc == 9, "invalidArguments");
      int port = std::stoi(v[2]);
      string token = v[3];
      require(port > 0 && port < 65536 && token.size() == 64,
              "invalidArguments");
      Fd fd(socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0));
      require(fd.n >= 0, "socketFailed");
      timeval timeout{30, 0};
      setsockopt(fd.n, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
      setsockopt(fd.n, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
      sockaddr_in address{};
      address.sin_family = AF_INET;
      address.sin_port = htons(uint16_t(port));
      inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);
      require(connect(fd.n, reinterpret_cast<sockaddr *>(&address),
                      sizeof(address)) == 0,
              "connectionFailed");
      write_all(fd.n, token.data(), token.size());
      uint8_t accepted = 0;
      read_all(fd.n, &accepted, 1);
      require(accepted == 1, "invalidIdentity");
      std::cout << transfer_files(
          fd.n, v[5], string(v[4]) == "send",
          {std::stoull(v[6]), std::stoull(v[7]), std::stoull(v[8])});
      return 0;
    }
    require(argc >= 5, "invalidArguments");
    auto job = job_path(v);
    if (op == "prepare" || op == "prepare_workspace") {
      require(argc == (op == "prepare" ? 11 : 20), "invalidArguments");
      directory(v[2]);
      require(mkdir(job.c_str(), 0700) == 0, "alreadyPrepared");
      atomic_file(job + "/token", v[4]);
      string command;
      char b[4096];
      ssize_t n;
      while ((n = read(0, b, sizeof(b))) > 0) {
        require(command.size() + size_t(n) <= 120 * 1024, "commandTooLarge");
        command.append(b, size_t(n));
      }
      require(n == 0 && command.find('\0') == string::npos, "invalidCommand");
      atomic_file(job + "/command", command);
      atomic_file(job + "/cwd", v[5]);
      atomic_file(job + "/shell", v[6]);
      atomic_file(job + "/home", v[7]);
      atomic_file(job + "/path", v[8]);
      atomic_file(job + "/limit", v[9]);
      atomic_file(job + "/lease", v[10]);
      if (op == "prepare_workspace") {
        string encoded;
        for (int i = 11; i < argc; ++i) { encoded += v[i]; encoded += '\0'; }
        atomic_file(job + "/workspaceArgs", encoded);
      }
      std::cout << "{\"version\":1,\"state\":\"prepared\"}";
    } else {
      authenticate(job, v[4]);
      if (op == "run")
        return run_job(job);
      if (op == "cancel") {
        atomic_file(job + "/cancel", "1");
        std::cout << "{\"version\":1,\"state\":\"cancelling\"}";
      } else if (op == "poll") {
        require(argc == 8, "invalidArguments");
        int64_t a = std::stoll(v[5]), b = std::stoll(v[6]);
        if (!exists(job + "/result") && string(v[7]) == "renew")
          atomic_file(job + "/lease", std::to_string(now_ms() + 30000));
        auto out = page(job + "/stdout", a, 8192),
             err = page(job + "/stderr", b, 8192);
        auto result = exists(job + "/result")
                          ? read_file(job + "/result")
                          : "{\"version\":1,\"state\":\"running\"}";
        std::cout << "{\"version\":1,\"stdout\":" << quote(base64(out))
                  << ",\"stderr\":" << quote(base64(err))
                  << ",\"outOffset\":" << a << ",\"errOffset\":" << b
                  << ",\"result\":" << result << "}";
      } else if (op == "cleanup") {
        require(exists(job + "/result") || !exists(job + "/started"),
                "stillRunning");
        DIR *d = opendir(job.c_str());
        require(d != nullptr, "directoryFailed");
        while (auto *i = readdir(d)) {
          string n = i->d_name;
          if (n != "." && n != "..")
            unlink((job + "/" + n).c_str());
        }
        closedir(d);
        require(rmdir(job.c_str()) == 0, "cleanupFailed");
        std::cout << "{\"version\":1,\"ok\":true}";
      } else
        throw std::runtime_error("invalidOperation");
    }
    return 0;
  } catch (const std::exception &e) {
    std::cout << "{\"version\":1,\"error\":" << quote(e.what()) << "}";
    return 125;
  }
}
