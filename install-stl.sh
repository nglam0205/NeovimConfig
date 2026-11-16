#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TERMUX_PREFIX="${TERMUX_PREFIX:-${PREFIX:-/data/data/com.termux/files/usr}}"

log() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2
  exit 1
}

install_termux_headers() {
  local hdr="$TERMUX_PREFIX/include/bits/stdc++.h"
  mkdir -p "$TERMUX_PREFIX/include/bits"

  if [ -e "$hdr" ] && ! grep -q 'TERMUX_BITS_STDCXX_H' "$hdr" 2>/dev/null; then
    warn "Existing $hdr is not the Termux compatibility header; leaving it untouched."
    return 0
  fi

  cat >"$hdr" <<'HEADER'
#ifndef TERMUX_BITS_STDCXX_H
#define TERMUX_BITS_STDCXX_H

#include <algorithm>
#include <array>
#include <atomic>
#include <bitset>
#include <cassert>
#include <cctype>
#include <cerrno>
#include <cfenv>
#include <cfloat>
#include <cinttypes>
#include <climits>
#include <clocale>
#include <cmath>
#include <complex>
#include <condition_variable>
#include <csetjmp>
#include <csignal>
#include <cstdarg>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <cuchar>
#include <cwchar>
#include <cwctype>
#include <deque>
#include <exception>
#include <forward_list>
#include <fstream>
#include <functional>
#include <future>
#include <initializer_list>
#include <iomanip>
#include <ios>
#include <iosfwd>
#include <iostream>
#include <istream>
#include <iterator>
#include <limits>
#include <list>
#include <locale>
#include <map>
#include <memory>
#include <mutex>
#include <new>
#include <numeric>
#include <ostream>
#include <queue>
#include <random>
#include <ratio>
#include <regex>
#include <scoped_allocator>
#include <set>
#include <sstream>
#include <stack>
#include <stdexcept>
#include <streambuf>
#include <string>
#include <system_error>
#include <thread>
#include <tuple>
#include <typeindex>
#include <typeinfo>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <valarray>
#include <vector>

#if __cplusplus >= 201703L
#include <any>
#include <charconv>
#include <filesystem>
#include <memory_resource>
#include <optional>
#include <shared_mutex>
#include <string_view>
#include <variant>
#endif

#if __cplusplus >= 202002L
#include <barrier>
#include <bit>
#include <compare>
#include <concepts>
#include <coroutine>
#include <format>
#include <latch>
#include <numbers>
#include <ranges>
#include <semaphore>
#include <source_location>
#include <span>
#include <syncstream>
#include <version>
#endif

#if __cplusplus > 202002L
#include <expected>
#include <mdspan>
#include <print>
#endif

#endif
HEADER

  [ -s "$hdr" ] || die "Failed to write $hdr"
  ok "Termux C++ compatibility header ready: $hdr"
}

install_termux_headers
