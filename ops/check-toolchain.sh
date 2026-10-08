#!/usr/bin/env bash
# check-toolchain.sh: report which Pi Arena tools are installed and working.
# Runs on the Arch desktop (x86_64, uses the cross toolchain + qemu-aarch64)
# and on the Pi (aarch64, runs everything natively). Changes nothing.
# Usage: bash check-toolchain.sh        exit code = number of failures
set -u

pass=0
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'OK    %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$name"
    fail=$((fail + 1))
  fi
}

section() { printf '\n== %s\n' "$1"; }

arch=$(uname -m)
if [ "$arch" = "aarch64" ]; then
  AS=as LD=ld GDB=gdb RUN=""
else
  AS=aarch64-linux-gnu-as LD=aarch64-linux-gnu-ld GDB=aarch64-linux-gnu-gdb RUN=qemu-aarch64
fi

section "Network (DNS must work before anything downloads)"
check "resolve hackage.haskell.org" getent hosts hackage.haskell.org
check "resolve hex.pm" getent hosts hex.pm

section "C"
printf 'int main(void){return 0;}\n' > "$tmp/t.c"
check "gcc with ASan/UBSan" gcc -Wall -Wextra -fsanitize=address,undefined -o "$tmp/t" "$tmp/t.c"
check "sanitized binary runs" "$tmp/t"
check "make" make --version
check "gdb" gdb --version
check "valgrind" valgrind --version
check "strace" strace -V
check "perf can count" perf stat -e task-clock true

section "ARM64 assembly ($arch)"
cat > "$tmp/h.s" <<'EOF'
    .section .rodata
msg: .ascii "ok\n"
    .text
    .globl _start
_start:
    mov x0, #1
    ldr x1, =msg
    mov x2, #3
    mov x8, #64
    svc #0
    mov x0, #0
    mov x8, #93
    svc #0
EOF
check "assemble" "$AS" -o "$tmp/h.o" "$tmp/h.s"
check "link" "$LD" -o "$tmp/h" "$tmp/h.o"
if [ -n "$RUN" ]; then
  check "run under qemu-aarch64" "$RUN" "$tmp/h"
else
  check "run natively" "$tmp/h"
fi
check "debugger ($GDB)" "$GDB" --version
check "objdump" objdump --version

section "Haskell"
check "ghc" ghc --version
check "ghc evaluates" ghc -e 'print (sum [1..10 :: Int])'
check "cabal" cabal --version
if [ "$arch" != "aarch64" ]; then
  check "stack" stack --version
  check "haskell-language-server" haskell-language-server-wrapper --version
fi

section "Erlang"
check "erl" erl -noshell -eval 'halt().'
check "OTP 27 or newer" erl -noshell -eval \
  'R = list_to_integer(erlang:system_info(otp_release)), halt(if R >= 27 -> 0; true -> 1 end).'
check "built-in json module" erl -noshell -eval \
  'try json:encode(#{a => 1}) of _ -> halt(0) catch _:_ -> halt(1) end.'
check "rebar3" rebar3 version

section "SQL, shell, misc"
check "sqlite3" sqlite3 -version
check "sqlite window functions" sqlite3 :memory: 'select lag(1) over ();'
check "shellcheck" shellcheck --version
check "awk is gawk" awk --version
check "jq" jq --version
check "netcat" command -v nc
check "git" git --version

printf '\n%d OK, %d FAIL\n' "$pass" "$fail"
exit "$fail"
