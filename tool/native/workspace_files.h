#pragma once
// Typed workspace operations. No model-supplied shell or interpreter dependency.
static string ws_path(const string &root, const string &relative) {
  require(!relative.empty() && relative[0] != '/' && relative.find('\\') == string::npos,
          "invalidPath");
  string path = root;
  size_t start = 0;
  while (start <= relative.size()) {
    auto end = relative.find('/', start);
    string part = relative.substr(start, end == string::npos ? end : end - start);
    require(part != "..", "invalidPath");
    if (!part.empty() && part != ".") path += "/" + part;
    if (end == string::npos) break;
    start = end + 1;
  }
  // Reject links in every existing component, including the managed root.
  for (size_t i = 1; i <= path.size(); ++i) {
    if (i < path.size() && path[i] != '/') continue;
    struct stat st{};
    if (lstat(path.substr(0, i).c_str(), &st) == 0)
      require(!S_ISLNK(st.st_mode), "invalidPath");
    else require(errno == ENOENT, "fileUnavailable");
  }
  return path;
}
static void ws_mkdir(const string &path) {
  if (exists(path)) {
    struct stat s{};
    require(lstat(path.c_str(), &s) == 0 && S_ISDIR(s.st_mode), "notDirectory");
    return;
  }
  auto slash = path.rfind('/');
  require(slash != string::npos && slash > 0, "invalidPath");
  ws_mkdir(path.substr(0, slash));
  require(mkdir(path.c_str(), 0700) == 0, "directoryFailed");
}
static std::vector<string> ws_names(const string &path) {
  DIR *dir = opendir(path.c_str());
  require(dir != nullptr, "directoryFailed");
  std::vector<string> names;
  try {
    while (auto *entry = readdir(dir)) {
      require(!stopping, "cancelled");
      string name = entry->d_name;
      if (name == "." || name == "..") continue;
      require(names.size() < 100000, "directoryLimit");
      names.push_back(name);
    }
  } catch (...) { closedir(dir); throw; }
  closedir(dir);
  std::sort(names.begin(), names.end());
  return names;
}
static void ws_delete(const string &path) {
  require(!stopping, "cancelled");
  struct stat s{};
  if (lstat(path.c_str(), &s) != 0) { require(errno == ENOENT, "fileUnavailable"); return; }
  if (S_ISDIR(s.st_mode)) {
    DIR *dir = opendir(path.c_str());
    require(dir != nullptr, "directoryFailed");
    try {
      while (auto *entry = readdir(dir)) {
        string name = entry->d_name;
        if (name != "." && name != "..") ws_delete(path + "/" + name);
      }
    } catch (...) { closedir(dir); throw; }
    closedir(dir);
    require(rmdir(path.c_str()) == 0, "directoryFailed");
  } else require(unlink(path.c_str()) == 0, "writeFailed");
}
static string ws_page(const string &path, int64_t offset, int64_t limit) {
  require(offset >= 1 && limit >= 1 && limit <= 2000, "invalidArguments");
  Fd file(open(path.c_str(), O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC));
  require(file.n >= 0, "fileUnavailable");
  struct stat st{};
  require(fstat(file.n, &st) == 0 && S_ISREG(st.st_mode), "notText");
  int64_t line = 1, count = 0;
  string body, current;
  bool more = false, finished = false;
  auto accept = [&]() {
    if (line < offset) return true;
    if (count >= limit || body.size() + current.size() + (count ? 1 : 0) > 16384) return false;
    require(current.find('\0') == string::npos, "notText");
    if (!current.empty() && current.back() == '\r') current.pop_back();
    if (count++) body += '\n';
    body += current; current.clear(); return true;
  };
  char bytes[8192]; ssize_t n = 0;
  while (!finished && (n = read(file.n, bytes, sizeof(bytes))) > 0) {
    require(!stopping, "cancelled");
    for (ssize_t i = 0; i < n; ++i) {
      if (bytes[i] == '\n') {
        if (!accept()) { more = finished = true; break; }
        ++line;
      } else if (line >= offset) {
        if (count == limit) { more = finished = true; break; }
        if (body.size() + current.size() + (count ? 1 : 0) + 1 > 16384) {
          require(count > 0, "lineTooLong"); more = finished = true; break;
        }
        current += bytes[i];
      }
    }
  }
  require(n >= 0, "readFailed");
  if (!finished) { require(line >= offset, "offsetOutOfRange"); more = !accept(); }
  return "{\"version\":1,\"text\":" + quote(base64(body)) + ",\"startLine\":" +
      std::to_string(offset) + ",\"lineCount\":" + std::to_string(count) +
      ",\"hasMore\":" + (more ? "true" : "false") + "}";
}
static string workspace_operation(int argc, char **v) {
  require(argc == 10 && id_ok(v[3]), "invalidArguments");
  string base = v[2], root = base + "/" + v[3], op = v[4];
  require(base == "/data/data/com.termux/files/home/.phase/workspaces", "invalidPath");
  string path = ws_path(root, v[5]);
  const string stage_root = base + "/.staging/" + v[3];
  if (op == "ensure") { ws_mkdir(path); return "{\"version\":1,\"ok\":true}"; }
  if (op == "stage") {
    ws_mkdir(root); ws_mkdir(ws_path(stage_root, "."));
    return "{\"version\":1,\"ok\":true}";
  }
  if (op == "deleteRoot") {
    require(path == root, "invalidPath"); ws_delete(root);
    ws_delete(ws_path(stage_root, "."));
    return "{\"version\":1,\"ok\":true}";
  }
  if (op == "discard") {
    require(id_ok(v[8]), "invalidArguments");
    ws_delete(ws_path(stage_root, v[8]));
    return "{\"version\":1,\"ok\":true}";
  }
  if (op == "commit") {
    require(path != root && id_ok(v[8]), "invalidPath");
    auto stage = ws_path(stage_root, v[8]);
    string expected = v[9];
    if (!expected.empty()) {
      struct stat current{};
      require(lstat(path.c_str(), &current) == 0 && S_ISREG(current.st_mode) &&
          current.st_size <= 2 * 1024 * 1024 && file_digest(path) == expected, "fileChanged");
    }
    ws_mkdir(path.substr(0, path.rfind('/')));
    ws_path(root, v[5]);
    require(rename(stage.c_str(), path.c_str()) == 0, "commitFailed");
    return "{\"version\":1,\"ok\":true}";
  }
  if (op == "page") return ws_page(path, std::stoll(v[6]), std::stoll(v[7]));
  struct stat st{};
  if (lstat(path.c_str(), &st) != 0) {
    require(errno == ENOENT, "fileUnavailable");
    if (op == "list" && path == root) return "{\"version\":1,\"entries\":[],\"total\":0}";
    require(op != "list", "fileMissing");
    return "{\"version\":1,\"type\":\"missing\",\"size\":0}";
  }
  if (op == "stat") {
    string kind = S_ISREG(st.st_mode) ? "file" : S_ISDIR(st.st_mode) ? "directory" : "special";
    string hash = string(v[6]) == "1" && S_ISREG(st.st_mode) && st.st_size <= 64 * 1024 * 1024 ? file_digest(path) : "";
    return "{\"version\":1,\"type\":" + quote(kind) + ",\"size\":" + std::to_string(st.st_size) + ",\"digest\":" + quote(hash) + "}";
  }
  require(op == "list" && S_ISDIR(st.st_mode), "notDirectory");
  auto names = ws_names(path);
  size_t offset = std::stoull(v[6]), end = offset;
  string entries;
  for (; end < names.size() && end - offset < 100; ++end) {
    struct stat item{};
    require(lstat((path + "/" + names[end]).c_str(), &item) == 0, "fileUnavailable");
    string kind = S_ISREG(item.st_mode) ? "file" : S_ISDIR(item.st_mode) ? "directory" : "link";
    string row = "{\"name\":" + quote(names[end]) + ",\"type\":" + quote(kind) + ",\"size\":" + std::to_string(item.st_size) + "}";
    if (entries.size() + row.size() > 12000 && !entries.empty()) break;
    if (!entries.empty()) entries += ',';
    entries += row;
  }
  return "{\"version\":1,\"entries\":[" + entries + "],\"total\":" + std::to_string(names.size()) + ",\"nextOffset\":" + std::to_string(end) + "}";
}
