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

// SHA-256 for streaming transfer integrity; no platform crypto/Termux package
// dependency.
class Sha256 {
  uint32_t h[8]{0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
  uint8_t buffer[64]{};
  size_t used = 0;
  uint64_t length = 0;
  static uint32_t r(uint32_t v, int n) { return (v >> n) | (v << (32 - n)); }
  void block(const uint8_t *p) {
    static constexpr uint32_t k[64]{
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
        0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
        0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
        0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};
    uint32_t w[64];
    for (int i = 0; i < 16; i++)
      w[i] = uint32_t(p[i * 4]) << 24 | uint32_t(p[i * 4 + 1]) << 16 |
             uint32_t(p[i * 4 + 2]) << 8 | p[i * 4 + 3];
    for (int i = 16; i < 64; i++)
      w[i] = w[i - 16] +
             (r(w[i - 15], 7) ^ r(w[i - 15], 18) ^ (w[i - 15] >> 3)) +
             w[i - 7] + (r(w[i - 2], 17) ^ r(w[i - 2], 19) ^ (w[i - 2] >> 10));
    uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5],
             g = h[6], z = h[7];
    for (int i = 0; i < 64; i++) {
      uint32_t t = z + (r(e, 6) ^ r(e, 11) ^ r(e, 25)) + ((e & f) ^ (~e & g)) +
                   k[i] + w[i],
               u = (r(a, 2) ^ r(a, 13) ^ r(a, 22)) +
                   ((a & b) ^ (a & c) ^ (b & c));
      z = g;
      g = f;
      f = e;
      e = d + t;
      d = c;
      c = b;
      b = a;
      a = t + u;
    }
    h[0] += a;
    h[1] += b;
    h[2] += c;
    h[3] += d;
    h[4] += e;
    h[5] += f;
    h[6] += g;
    h[7] += z;
  }

public:
  void add(const uint8_t *p, size_t n) {
    length += n;
    while (n) {
      size_t take = std::min(n, 64 - used);
      memcpy(buffer + used, p, take);
      used += take;
      p += take;
      n -= take;
      if (used == 64) {
        block(buffer);
        used = 0;
      }
    }
  }
  std::array<uint8_t, 32> finish() {
    uint64_t bits = length * 8;
    uint8_t one = 0x80, zero = 0;
    add(&one, 1);
    while (used != 56)
      add(&zero, 1);
    uint8_t size[8];
    for (int i = 0; i < 8; i++)
      size[i] = uint8_t(bits >> (56 - i * 8));
    add(size, 8);
    std::array<uint8_t, 32> out{};
    for (int i = 0; i < 32; i++)
      out[i] = uint8_t(h[i / 4] >> (24 - (i % 4) * 8));
    return out;
  }
};
static void put_int(int fd, uint64_t value, int bytes) {
  uint8_t b[8];
  for (int i = 0; i < bytes; i++)
    b[i] = uint8_t(value >> (8 * (bytes - i - 1)));
  write_all(fd, b, size_t(bytes));
}
static uint64_t get_int(int fd, int bytes) {
  uint8_t b[8];
  read_all(fd, b, size_t(bytes));
  uint64_t n = 0;
  for (int i = 0; i < bytes; i++)
    n = (n << 8) | b[i];
  return n;
}
static void put_text(int fd, const string &s) {
  put_int(fd, s.size(), 4);
  write_all(fd, s.data(), s.size());
}
static string get_text(int fd) {
  size_t n = size_t(get_int(fd, 4));
  require(n <= 4096, "invalidPath");
  string s(n, '\0');
  read_all(fd, s.data(), n);
  return s;
}
static bool relative_ok(const string &s) {
  if (s.empty())
    return true;
  if (s.front() == '/' || s.find('\0') != string::npos ||
      s.find('\\') != string::npos)
    return false;
  size_t from = 0;
  while (from <= s.size()) {
    auto end = s.find('/', from);
    auto part = s.substr(from, end == string::npos ? end : end - from);
    if (part.empty() || part == "." || part == "..")
      return false;
    if (end == string::npos)
      break;
    from = end + 1;
  }
  return true;
}
static void no_links(const string &path, bool missing) {
  require(!path.empty() && path.front() == '/' &&
              path.find('\0') == string::npos,
          "invalidPath");
  string current;
  size_t from = 1;
  while (from <= path.size()) {
    auto end = path.find('/', from);
    auto part = path.substr(from, end == string::npos ? end : end - from);
    if (!part.empty()) {
      require(part != "." && part != "..", "invalidPath");
      current += "/" + part;
      struct stat s{};
      if (lstat(current.c_str(), &s) != 0) {
        require(missing && errno == ENOENT, "fileUnavailable");
      } else
        require(!S_ISLNK(s.st_mode), "symbolicLink");
    }
    if (end == string::npos)
      break;
    from = end + 1;
  }
}
struct Entry {
  string path;
  bool dir;
  uint64_t size;
};

static void scan(const string &root, const string &relative,
                 std::vector<Entry> &entries, uint64_t &total,
                 const TransferLimits &limits) {
  string path = root + (relative.empty() ? "" : "/" + relative);
  struct stat s{};
  require(lstat(path.c_str(), &s) == 0, "fileUnavailable");
  require(S_ISDIR(s.st_mode) || S_ISREG(s.st_mode), "unsupportedFile");
  uint64_t size = S_ISREG(s.st_mode) ? uint64_t(s.st_size) : 0;
  require(size <= limits.file && total + size <= limits.total &&
              entries.size() < limits.count,
          "transferLimit");
  total += size;
  entries.push_back({relative, S_ISDIR(s.st_mode), size});
  if (S_ISDIR(s.st_mode)) {
    DIR *d = opendir(path.c_str());
    require(d != nullptr, "directoryFailed");
    std::vector<string> names;
    while (auto *item = readdir(d)) {
      string name = item->d_name;
      if (name != "." && name != "..") {
        if (names.size() + entries.size() >= limits.count) {
          closedir(d);
          throw std::runtime_error("transferLimit");
        }
        names.push_back(name);
      }
    }
    closedir(d);
    std::sort(names.begin(), names.end());
    for (auto &name : names)
      scan(root, relative.empty() ? name : relative + "/" + name, entries,
           total, limits);
  }
}
static string parent_path(const string &s) {
  auto p = s.find_last_of('/');
  return p == 0 ? "/" : s.substr(0, p);
}
static void mkdirs(const string &path, std::vector<string> *created = nullptr) {
  no_links(path, true);
  if (exists(path)) {
    struct stat s{};
    require(stat(path.c_str(), &s) == 0 && S_ISDIR(s.st_mode), "typeConflict");
    return;
  }
  mkdirs(parent_path(path), created);
  require(mkdir(path.c_str(), 0700) == 0, "directoryFailed");
  if (created)
    created->push_back(path);
}
string transfer_files(int fd, const string &root, bool sending,
                      const TransferLimits &limits) {
  std::vector<Entry> entries;
  uint64_t total = 0;
  std::vector<string> temporary, created;
  size_t completed = 0;
  bool committing = false;
  try {
    no_links(root, !sending);
    if (sending) {
      scan(root, "", entries, total, limits);
      size_t metadata = 0;
      for (auto &e : entries)
        metadata += e.path.size() + 13;
      require(metadata <= 65536, "transferLimit");
      put_int(fd, entries.size(), 4);
      for (auto &e : entries) {
        put_int(fd, e.dir ? 2 : 1, 1);
        put_text(fd, e.path);
        put_int(fd, e.size, 8);
      }
    } else {
      uint64_t count = get_int(fd, 4);
      require(count > 0 && count <= limits.count, "transferLimit");
      for (uint64_t i = 0; i < count; i++) {
        auto type = get_int(fd, 1);
        auto path = get_text(fd);
        auto size = get_int(fd, 8);
        require((type == 1 || type == 2) && relative_ok(path) &&
                    (i ? !path.empty() : path.empty()) && size <= limits.file &&
                    total + size <= limits.total && (type != 2 || size == 0),
                "invalidManifest");
        for (auto &e : entries)
          require(e.path != path, "invalidManifest");
        if (i) {
          auto pos = path.find_last_of('/');
          auto parent = pos == string::npos ? "" : path.substr(0, pos);
          require(std::any_of(entries.begin(), entries.end(),
                              [&](const Entry &e) {
                                return e.dir && e.path == parent;
                              }),
                  "invalidManifest");
        }
        total += size;
        entries.push_back({path, type == 2, size});
        size_t metadata = 0;
        for (auto &e : entries)
          metadata += e.path.size() + 13;
        require(metadata <= 65536, "transferLimit");
      }
      for (auto &e : entries) {
        auto path = root + (e.path.empty() ? "" : "/" + e.path);
        no_links(path, true);
        struct stat s{};
        if (lstat(path.c_str(), &s) == 0)
          require(e.dir ? S_ISDIR(s.st_mode) : S_ISREG(s.st_mode),
                  "typeConflict");
      }
    }
    uint8_t buffer[32768];
    for (size_t i = 0; i < entries.size(); i++) {
      auto &e = entries[i];
      if (e.dir)
        continue;
      auto path = root + (e.path.empty() ? "" : "/" + e.path);
      Sha256 digest;
      if (sending) {
        no_links(path, false);
        Fd source(open(path.c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC));
        require(source.n >= 0, "fileUnavailable");
        struct stat before{}, after{};
        require(fstat(source.n, &before) == 0 && S_ISREG(before.st_mode) &&
                    uint64_t(before.st_size) == e.size,
                "sourceChanged");
        uint64_t left = e.size;
        while (left) {
          size_t n = size_t(std::min<uint64_t>(left, sizeof(buffer)));
          read_all(source.n, buffer, n);
          digest.add(buffer, n);
          write_all(fd, buffer, n);
          left -= n;
        }
        require(fstat(source.n, &after) == 0 &&
                    before.st_size == after.st_size &&
                    before.st_mtim.tv_sec == after.st_mtim.tv_sec &&
                    before.st_mtim.tv_nsec == after.st_mtim.tv_nsec,
                "sourceChanged");
        auto hash = digest.finish();
        write_all(fd, hash.data(), hash.size());
      } else {
        mkdirs(parent_path(path), &created);
        string pattern = parent_path(path) + "/.phase-transfer-XXXXXX";
        std::vector<char> temp(pattern.begin(), pattern.end());
        temp.push_back(0);
        Fd target(mkstemp(temp.data()));
        require(target.n >= 0, "writeFailed");
        temporary.push_back(temp.data());
        uint64_t left = e.size;
        while (left) {
          size_t n = size_t(std::min<uint64_t>(left, sizeof(buffer)));
          read_all(fd, buffer, n);
          digest.add(buffer, n);
          write_all(target.n, buffer, n);
          left -= n;
        }
        std::array<uint8_t, 32> hash{};
        read_all(fd, hash.data(), hash.size());
        require(hash == digest.finish() && fsync(target.n) == 0,
                "integrityFailed");
      }
    }
    if (sending) {
      require(get_int(fd, 1) == 1, "transferRejected");
      put_int(fd, 1, 1);
      auto ok = get_int(fd, 1);
      completed = size_t(get_int(fd, 4));
      require(completed <= entries.size(), "invalidManifest");
      require(ok == 1 && completed == entries.size(), "commitFailed");
    } else {
      put_int(fd, 1, 1);
      require(get_int(fd, 1) == 1, "transferCancelled");
      committing = true;
      size_t ti = 0;
      for (auto &e : entries) {
        if (stopping)
          throw std::runtime_error("cancelled");
        auto path = root + (e.path.empty() ? "" : "/" + e.path);
        no_links(path, true);
        if (e.dir)
          mkdirs(path, &created);
        else {
          require(rename(temporary[ti].c_str(), path.c_str()) == 0,
                  "commitFailed");
          temporary[ti++].clear();
        }
        completed++;
      }
      put_int(fd, 1, 1);
      put_int(fd, completed, 4);
    }
    return "{\"version\":1,\"ok\":true,\"bytes\":" + std::to_string(total) +
           ",\"completedCount\":" + std::to_string(completed) + "}";
  } catch (...) {
    if (!sending && committing) {
      try {
        put_int(fd, 0, 1);
        put_int(fd, completed, 4);
      } catch (...) {
      }
    }
    for (auto &path : temporary)
      if (!path.empty())
        unlink(path.c_str());
    for (auto i = created.rbegin(); i != created.rend(); ++i) {
      bool committed = false;
      for (size_t n = 0; n < completed; n++)
        if (*i == root + (entries[n].path.empty() ? "" : "/" + entries[n].path))
          committed = true;
      if (!committed)
        rmdir(i->c_str());
    }
    throw;
  }
}

std::string file_digest(const std::string &path) {
  Fd file(open(path.c_str(), O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC));
  require(file.n >= 0, "fileUnavailable");
  struct stat info{};
  require(fstat(file.n, &info) == 0 && S_ISREG(info.st_mode), "unsupportedFile");
  require(info.st_size <= 64 * 1024 * 1024, "fileTooLarge");
  Sha256 hash;
  size_t size = 0;
  uint8_t bytes[32768];
  ssize_t n;
  while ((n = read(file.n, bytes, sizeof(bytes))) > 0) {
    require(!stopping, "cancelled");
    size += size_t(n);
    require(size <= 64 * 1024 * 1024, "fileTooLarge");
    hash.add(bytes, size_t(n));
  }
  require(n == 0, "readFailed");
  const char *hex = "0123456789abcdef";
  string result;
  for (auto b : hash.finish()) { result += hex[b >> 4]; result += hex[b & 15]; }
  return result;
}
