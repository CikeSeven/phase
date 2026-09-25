#pragma once
#include <cstdint>
#include <string>
struct TransferLimits {
  uint64_t file, total, count;
};
std::string transfer_files(int fd, const std::string &root, bool sending,
                           const TransferLimits &limits);
