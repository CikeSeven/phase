#pragma once
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
using std::string;
extern volatile sig_atomic_t stopping;
inline void require(bool ok, const char *error) {
  if (ok)
    return;
  const string operation(error);
  if (operation == "writeFailed" || operation == "readFailed" ||
      operation == "fileUnavailable" || operation == "directoryFailed" ||
      operation == "commitFailed" || operation == "logWriteFailed") {
    if (errno == EACCES || errno == EPERM)
      throw std::runtime_error("filePermissionDenied");
    if (errno == ENOSPC || errno == EDQUOT)
      throw std::runtime_error("spaceUnavailable");
    if (errno == EROFS)
      throw std::runtime_error("readOnlyFileSystem");
    if (errno == ENOENT)
      throw std::runtime_error("fileMissing");
    if (errno == ENOTDIR)
      throw std::runtime_error("notDirectory");
  }
  throw std::runtime_error(error);
}
inline bool exists(const string &path) {
  struct stat s{};
  return lstat(path.c_str(), &s) == 0;
}
struct Fd {
  int n = -1;
  explicit Fd(int value = -1) : n(value) {}
  ~Fd() {
    if (n >= 0)
      close(n);
  }
  Fd(const Fd &) = delete;
  Fd &operator=(const Fd &) = delete;
};
inline void write_all(int fd, const void *bytes, size_t size) {
  auto p = static_cast<const uint8_t *>(bytes);
  while (size) {
    if (stopping)
      throw std::runtime_error("cancelled");
    ssize_t n = write(fd, p, size);
    if (n < 0 && errno == EINTR)
      continue;
    require(n > 0, "writeFailed");
    size -= size_t(n);
    p += n;
  }
}
inline void read_all(int fd, void *bytes, size_t size) {
  auto p = static_cast<uint8_t *>(bytes);
  while (size) {
    if (stopping)
      throw std::runtime_error("cancelled");
    ssize_t n = read(fd, p, size);
    if (n < 0 && errno == EINTR)
      continue;
    if (n == 0)
      throw std::runtime_error("transferDisconnected");
    require(n > 0, "readFailed");
    size -= size_t(n);
    p += n;
  }
}
