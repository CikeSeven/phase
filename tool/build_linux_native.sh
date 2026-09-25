#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ndk_dir="${1:-${ANDROID_NDK_ROOT:-$HOME/android-sdk/ndk/28.2.13676358}}"
output="$PWD/build/linux-native"
source_dir="$output/source"
jni_dir="$output/jniLibs/arm64-v8a"
llvm="$ndk_dir/toolchains/llvm/prebuilt/linux-x86_64/bin"
cc="$llvm/aarch64-linux-android24-clang"
# Versioned source archives and local build inputs determine the cache key.
fingerprint=$(cat tool/build_linux_native.sh tool/native/talloc_replace.h tool/native/process_runner.c tool/native/command_runner.cpp tool/native/command_transfer.cpp tool/native/command_transfer.h tool/native/command_common.h "$ndk_dir/source.properties" | sha256sum | cut -d ' ' -f1)
if [[ -f "$output/stamp" && "$(cat "$output/stamp")" == "$fingerprint" && -f "$jni_dir/libphase_proot.so" && -f "$jni_dir/libphase_loader.so" && -f "$jni_dir/libphase_talloc.so" && -f "$jni_dir/libphase_exec.so" && -f "$jni_dir/libphase_command.so" ]]; then exit 0; fi
mkdir -p "$source_dir" "$jni_dir"
fetch() {
  local url="$1" file="$2" digest="$3"
  if ! echo "$digest  $file" | sha256sum -c --status 2>/dev/null; then
    curl --fail --location --retry 2 --connect-timeout 20 --max-time 180 "$url" -o "$file.part"
    echo "$digest  $file.part" | sha256sum -c --status
    mv "$file.part" "$file"
  fi
}
fetch https://codeload.github.com/termux/proot/tar.gz/refs/tags/v5.1.107.92 "$source_dir/proot.tar.gz" a1b070f55ec32b78e5033621476533d7230eb110275fe0cc3ee79c4fb334cfaa
fetch https://www.samba.org/ftp/talloc/talloc-2.4.3.tar.gz "$source_dir/talloc.tar.gz" dc46c40b9f46bb34dd97fe41f548b0e8b247b77a918576733c528e83abd854dd
tar -xzf "$source_dir/proot.tar.gz" -C "$source_dir"
tar -xzf "$source_dir/talloc.tar.gz" -C "$source_dir"
sed -i '1i #include <string.h>' "$source_dir/proot-5.1.107.92/src/extension/ashmem_memfd/ashmem_memfd.c"
cp tool/native/talloc_replace.h "$source_dir/talloc-2.4.3/replace.h"
"$cc" -O2 -fPIC -shared -D_GNU_SOURCE -I"$source_dir/talloc-2.4.3" "$source_dir/talloc-2.4.3/talloc.c" -Wl,-soname,libphase_talloc.so,-z,max-page-size=16384 -o "$jni_dir/libphase_talloc.so"
# loader is a static executable; PRoot obtains its packaged path from PROOT_LOADER.
make -C "$source_dir/proot-5.1.107.92/src" clean > "$output/proot-clean.log" 2>&1
make -C "$source_dir/proot-5.1.107.92/src" -j4 \
  GIT=false CC="$cc" STRIP="$llvm/llvm-strip" OBJCOPY="$llvm/llvm-objcopy" OBJDUMP="$llvm/llvm-objdump" \
  PROOT_UNBUNDLE_LOADER=/unused \
  CPPFLAGS="-D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -DARG_MAX=131072 -DVERSION=\\\"5.1.107.92\\\" -I. -I$source_dir/talloc-2.4.3" \
  LDFLAGS="-L$jni_dir -lphase_talloc -Wl,-z,noexecstack,-z,max-page-size=16384" \
  > "$output/proot-build.log" 2>&1 || { tail -60 "$output/proot-build.log"; exit 1; }
cp "$source_dir/proot-5.1.107.92/src/proot" "$jni_dir/libphase_proot.so"
cp "$source_dir/proot-5.1.107.92/src/loader/loader" "$jni_dir/libphase_loader.so"
"$cc" -O2 -Wall -Wextra -Werror tool/native/process_runner.c -Wl,-z,max-page-size=16384 -o "$jni_dir/libphase_exec.so"
"$llvm/aarch64-linux-android24-clang++" -std=c++17 -O2 -Wall -Wextra -Werror -static-libstdc++ tool/native/command_runner.cpp tool/native/command_transfer.cpp -Wl,-z,max-page-size=16384 -o "$jni_dir/libphase_command.so"
"$llvm/llvm-strip" "$jni_dir/"*.so
printf '%s' "$fingerprint" > "$output/stamp"
