#!/usr/bin/env bash
# setup-box.sh - reproduce cdr4eelz's CS150 box customisations on a fresh
# Debian 13 (trixie) box image. Idempotent: safe to re-run.
# DRAFT - review before running. Logins are printed as manual steps at the end.
#
# Usage: bash setup-box.sh [--no-virtualbox] [--no-docker] [--no-raylib]
set -euo pipefail

WANT_VBOX=1; WANT_DOCKER=1; WANT_RAYLIB=1
for a in "$@"; do
  case "$a" in
    --no-virtualbox) WANT_VBOX=0 ;;
    --no-docker)     WANT_DOCKER=0 ;;
    --no-raylib)     WANT_RAYLIB=0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
export DEBIAN_FRONTEND=noninteractive
APT_INSTALL=($SUDO apt-get install -y -q)
CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")"
log() { printf '\n==> %s\n' "$*"; }

# ---------------------------------------------------------------- apt repos
add_key() {  # add_key <url> <dest.gpg> <expected-fingerprint>
  local url="$1" dest="$2" fpr="$3" tmp
  if [ -s "$dest" ] && gpg --show-keys --with-colons "$dest" 2>/dev/null | grep -q "fpr:::::::::$fpr:"; then
    return 0
  fi
  tmp="$(mktemp)"
  curl -fsSL "$url" > "$tmp.raw"
  if grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$tmp.raw"; then gpg --dearmor < "$tmp.raw" > "$tmp"; else cp "$tmp.raw" "$tmp"; fi
  rm -f "$tmp.raw"
  gpg --show-keys --with-colons "$tmp" | grep -q "fpr:::::::::$fpr:" \
    || { echo "fingerprint mismatch for $url" >&2; rm -f "$tmp"; exit 1; }
  $SUDO install -m 0644 "$tmp" "$dest"; rm -f "$tmp"
}
add_list() {  # add_list <file> <line>
  local f="$1" line="$2"
  if [ "$(cat "$f" 2>/dev/null)" != "$line" ]; then
    echo "$line" | $SUDO tee "$f" >/dev/null
  fi
}

log "Base tools needed by this script"
$SUDO apt-get update -q
"${APT_INSTALL[@]}" ca-certificates curl wget gnupg

if [ "$WANT_RAYLIB" = 1 ]; then
  log "texus/raylib PPA (Ubuntu noble build, used on Debian trixie)"
  add_key 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xD91696CDE57C6F73D0F9D36C2C25A13B4164E492' \
          /usr/share/keyrings/texus-raylib.gpg D91696CDE57C6F73D0F9D36C2C25A13B4164E492
  add_list /etc/apt/sources.list.d/texus-raylib.list \
    'deb [signed-by=/usr/share/keyrings/texus-raylib.gpg] https://ppa.launchpadcontent.net/texus/raylib/ubuntu noble main'
fi

if [ "$WANT_VBOX" = 1 ]; then
  log "Oracle VirtualBox repo"
  add_key https://www.virtualbox.org/download/oracle_vbox_2016.asc \
          /usr/share/keyrings/oracle-virtualbox-2016.gpg B9F8D658297AF3EFC18D5CDFA2F683C52980AECF
  VBOX_SUITE="$CODENAME"
  curl -fsI "https://download.virtualbox.org/virtualbox/debian/dists/$VBOX_SUITE/Release" >/dev/null 2>&1 || VBOX_SUITE=bookworm
  add_list /etc/apt/sources.list.d/virtualbox.list \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $VBOX_SUITE contrib"
fi

$SUDO apt-get update -q

# ---------------------------------------------------------------- packages
log "Core dev tools"
"${APT_INSTALL[@]}" make g++ ripgrep tmux

log "CS150 MIPS toolchain + HDL sim (GCC 14 cross; gcc-12-mips variant is not in trixie)"
"${APT_INSTALL[@]}" gcc-mips-linux-gnu binutils-mips-linux-gnu iverilog

log "Terminal niceties (installed interactively on 2026-10-17)"
"${APT_INSTALL[@]}" less screen bash-completion ncurses-term screenie iselect bat

if [ "$WANT_RAYLIB" = 1 ]; then
  log "raylib (PPA libraylib6-dev) + X11/GL dev deps (originally for a raylib source build)"
  "${APT_INSTALL[@]}" pkg-config cmake libasound2-dev libx11-dev libxrandr-dev libxi-dev \
    libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev libwayland-dev libxkbcommon-dev
  "${APT_INSTALL[@]}" libraylib6-dev
fi

if [ "$WANT_DOCKER" = 1 ]; then
  log "Docker + QEMU/KVM"
  "${APT_INSTALL[@]}" docker.io qemu-system-x86 qemu-utils
fi

if [ "$WANT_VBOX" = 1 ]; then
  log "VirtualBox 7.2 (userland only; vboxdrv cannot load on this box's kernel - see INSTALLED.md)"
  # --no-install-recommends avoids pulling linux-headers-amd64 + a Debian kernel image/initramfs
  # that are useless here (the box boots an external 6.12.94+ kernel with modules disabled).
  $SUDO apt-get install -y -q --no-install-recommends virtualbox-7.2 || \
    echo "WARN: virtualbox-7.2 postinst reported problems (expected: no kernel module)" >&2
fi

# ---------------------------------------------------------------- non-apt
if ! command -v gh >/dev/null 2>&1; then
  log "gh CLI not found (normally ships with the box image at /usr/local/bin/gh); installing from GitHub apt repo"
  add_key https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          /usr/share/keyrings/githubcli-archive-keyring.gpg 2C6106201985B60E6C7AC87323F3D4EA75716059
  add_list /etc/apt/sources.list.d/github-cli.list \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
  $SUDO apt-get update -q && "${APT_INSTALL[@]}" gh
fi

if [ ! -x "$HOME/.grok/bin/grok" ]; then
  log "Grok Build CLI -> ~/.grok/bin (installer also appends a PATH block to ~/.bashrc)"
  curl -fsSL https://x.ai/cli/install.sh | bash
else
  log "Grok Build CLI already installed: $("$HOME/.grok/bin/grok" --version 2>/dev/null || echo present)"
fi

# ---------------------------------------------------------------- manual steps
cat <<'MSG'

==> Done. Manual steps (not scriptable):
  1. GitHub CLI login (device code):   gh auth login        # account: cdr4eelz
  2. Grok Build CLI login:             grok login --device-auth
  3. Docker daemon (no systemd here):  sudo dockerd > /tmp/dockerd.log 2>&1 &
  4. Optional, per shell, for CS150 build helpers (bin2mif etc.):
       export PATH="/workspace/cs150-1245/bin:$PATH"
  5. VirtualBox VMs will NOT start on this box (vboxdrv cannot be loaded: kernel
     booted with 'nomodule', kernel.modules_disabled=1). See INSTALLED.md.
MSG
