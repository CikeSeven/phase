/* Android bionic provides these libc interfaces; no Samba replacement library. */
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <sys/types.h>
#include <unistd.h>
#define HAVE_INTPTR_T 1
#define HAVE_VA_COPY 1
#define HAVE_CONSTRUCTOR_ATTRIBUTE 1
#define HAVE_SYS_AUXV_H 1
#define HAVE_GETAUXVAL 1
#define TALLOC_BUILD_VERSION_MAJOR 2
#define TALLOC_BUILD_VERSION_MINOR 4
#define TALLOC_BUILD_VERSION_RELEASE 3
#define PRINTF_ATTRIBUTE(a,b) __attribute__((format(printf,a,b)))
#define _PUBLIC_ __attribute__((visibility("default")))
#define discard_const(ptr) ((void *)((uintptr_t)(ptr)))

#define MIN(a,b) ((a) < (b) ? (a) : (b))
