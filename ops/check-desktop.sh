#!/usr/bin/env bash
# check-desktop.sh: is the Hyprland desktop from the install guide complete?
# Changes nothing. Pair it with check-toolchain.sh for the language tools.
# Usage: bash check-desktop.sh          exit code = number of failures
set -u

pass=0
fail=0
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

# shellcheck disable=SC2317  # called indirectly through check
hypr_version_ok() {
  # Lua config needs Hyprland 0.55 or newer
  local v
  v=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [ -n "$v" ] || return 1
  local major minor
  major=${v%%.*}
  minor=${v#*.}
  minor=${minor%%.*}
  [ "$major" -gt 0 ] || [ "$minor" -ge 55 ]
}

section "Hyprland"
check "Hyprland installed" command -v Hyprland
check "Hyprland 0.55+ (Lua config)" hypr_version_ok
check "hyprland.lua in place" test -f "$HOME/.config/hypr/hyprland.lua"
check "no leftover hyprland.conf" test ! -e "$HOME/.config/hypr/hyprland.conf"
for c in hyprlock hypridle hyprctl; do
  check "$c" command -v "$c"
done
check "xdg-desktop-portal-hyprland" test -x /usr/lib/xdg-desktop-portal-hyprland
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  check "Hyprland answers hyprctl" hyprctl version
fi

section "Desktop pieces"
for c in kitty waybar mako fuzzel swaybg grim slurp wl-copy cliphist brightnessctl playerctl wpctl pavucontrol firefox; do
  check "$c" command -v "$c"
done
check "JetBrainsMono Nerd Font" sh -c 'fc-list | grep -qi "JetBrainsMono Nerd"'
check "polkit agent unit" systemctl --user cat hyprpolkitagent.service
check "pipewire running" systemctl --user is-active pipewire
check "NetworkManager running" systemctl is-active NetworkManager

section "Terminal workflow"
check "tmux" command -v tmux
check "tmux config parses" tmux -L check -f "$HOME/.config/tmux/tmux.conf" start-server \; kill-server
check "nvim 0.11+ (built-in LSP config)" nvim --headless -c 'lua if vim.fn.has("nvim-0.11")==0 then os.exit(1) end' -c q
check "arena-dev on PATH" command -v arena-dev
check "pi-status on PATH" command -v pi-status

printf '\n%d OK, %d FAIL\n' "$pass" "$fail"
exit "$fail"
