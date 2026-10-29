#!/usr/bin/env bash
# setup-ise-docker.sh - build the Xilinx ISE 14.7 + ModelSim Docker image (Oracle Linux 6, like the ISE VM).
# Tested on Ubuntu 24.04 and Debian 13. Run as a normal sudo-capable user. Idempotent.
#
# Steps: 1) host packages  2) copy tools out of the VM disk READ-ONLY into $ISE_DIR (skipped if present)
#        3) assemble build context (this dir + pinned usb-driver source + VM dotfiles)  4) docker build  5) smoke test
#
# Env overrides:
#   ISE_DIR     dir for the copied tools (default: $ISE_DOCKER_DIR, ~/ise-docker or /workspace/ise-docker)
#   IMAGE       image tag (default ise14.7:ol6)
#   REPO        cs150 checkout mounted by run.sh (default: this repo)
#   QCOW2       VM disk image to copy tools from (attached read-only with qemu-nbd; default ~/Desktop/ise14.7.qcow2)
#   VM_ROOT     alternative to QCOW2: an already-mounted (read-only) VM root filesystem, e.g. /tmp/vmfs
#   USB_DRIVER_REPO / USB_DRIVER_REV   source of libusb-driver.so (default: GitHub mirror of Michael Gernoth's usb-driver)
#   FXLOAD_URL  fxload 2008_10_13 source tarball (sha256-checked)
#   SKIP_SMOKE=1     skip the smoke test;  SMOKE_FULL=1  also build proj_app6 and run hardware/sim (writes build outputs into REPO)
#   FORCE_EXTRACT=1  re-copy the tools;   NO_CACHE=1     docker build --no-cache
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/common.sh"
QCOW2=${QCOW2:-$HOME/Desktop/ise14.7.qcow2}
QCOW2_MD5=d0bac1b97f8f4c3c87a4be9c360e66f7
VM_ROOT=${VM_ROOT:-}
USB_DRIVER_REPO=${USB_DRIVER_REPO:-https://github.com/JohnDMcMaster/xilinx-usb-driver}
USB_DRIVER_REV=${USB_DRIVER_REV:-50cb89f583ec516ac7f5062a9aa9ced2b40c16c5}
FXLOAD_URL=${FXLOAD_URL:-https://deb.debian.org/debian/pool/main/f/fxload/fxload_0.0.20081013.orig.tar.gz}
FXLOAD_SHA256=0cc8bfd2a7cbba2f68e0c5767477634922287943c91dd9fcf029fc8b9d577858   # = upstream fxload-2008_10_13.tar.gz
NEED_GB=40

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 1. host ----------
log "Checking host"
[ "$(id -u)" -ne 0 ] || die "run as your normal user (sudo is used where needed), not root"
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*) info "${PRETTY_NAME:-$ID} OK" ;;
  *) info "WARNING: tested on Ubuntu 24.04 / Debian 13; found ${PRETTY_NAME:-unknown}" ;;
esac
info "ISE_DIR=$ISE_DIR  IMAGE=$IMAGE  REPO=$REPO  uid=$(id -u)"
pkgs=()
command -v docker >/dev/null || pkgs+=(docker.io)
command -v git    >/dev/null || pkgs+=(git)
command -v curl   >/dev/null || pkgs+=(curl)
command -v socat  >/dev/null || pkgs+=(socat)
command -v xauth  >/dev/null || pkgs+=(xauth)
need_extract=0
{ [ -d "$ISE_DIR/opt/Xilinx/14.7" ] && [ -z "${FORCE_EXTRACT:-}" ]; } || need_extract=1
[ $need_extract = 1 ] && [ -z "$VM_ROOT" ] && ! command -v qemu-nbd >/dev/null && pkgs+=(qemu-utils)
if [ ${#pkgs[@]} -gt 0 ]; then
  log "Installing host packages: ${pkgs[*]}"
  sudo apt-get update -q && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
fi
sudo systemctl enable --now docker >/dev/null 2>&1 || true
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi
info "docker: ${DOCKER[*]}"

# ---------- 2. tools from the VM (read-only) ----------
MNT=""; NBD=""; CTX=""
cleanup() {
  set +e
  [ -n "$MNT" ] && mountpoint -q "$MNT" && sudo umount "$MNT"
  [ -n "$MNT" ] && rmdir "$MNT" 2>/dev/null
  [ -n "$NBD" ] && sudo qemu-nbd -d "$NBD" >/dev/null
  [ -n "$CTX" ] && rm -rf "$CTX"
}
trap cleanup EXIT

if [ $need_extract = 0 ]; then
  log "Tools present in $ISE_DIR/opt; skipping extraction (FORCE_EXTRACT=1 to redo)"
else
  mkdir -p "$ISE_DIR"
  avail=$(df -BG --output=avail "$ISE_DIR" | tail -1 | tr -dc 0-9)
  [ "$avail" -ge "$NEED_GB" ] || die "need ~${NEED_GB} GB free in $ISE_DIR (tools ~36 GB), have ${avail} GB"
  SRC=$VM_ROOT
  if [ -z "$SRC" ]; then
    [ -f "$QCOW2" ] || die "no tools in $ISE_DIR/opt/Xilinx/14.7 and no VM disk at $QCOW2 (set QCOW2=, VM_ROOT= or ISE_DIR=)"
    log "Verifying qcow2 md5 (takes a while)"
    sum=$(md5sum "$QCOW2" | cut -d' ' -f1)
    [ "$sum" = "$QCOW2_MD5" ] && info "md5 OK" || info "WARNING: md5 $sum != expected $QCOW2_MD5 (continuing)"
    log "Attaching $QCOW2 read-only via qemu-nbd"
    sudo modprobe nbd max_part=8 || die "modprobe nbd failed (mount the VM root read-only yourself and pass VM_ROOT=)"
    for d in /sys/class/block/nbd*; do
      n=${d##*/}; [[ $n =~ ^nbd[0-9]+$ ]] || continue
      [ "$(cat "$d/size")" = 0 ] && { NBD=/dev/$n; break; }
    done
    [ -n "$NBD" ] && sudo qemu-nbd --read-only -f qcow2 -c "$NBD" "$QCOW2" || { NBD=""; die "qemu-nbd attach failed"; }
    sleep 2; sudo partprobe "$NBD" 2>/dev/null || true; sleep 1
    PART=""
    for p in "$NBD"p*; do
      [ -b "$p" ] || continue
      case "$(sudo blkid -o value -s TYPE "$p" 2>/dev/null)" in ext2|ext3|ext4) PART=$p; break;; esac
    done
    [ -n "$PART" ] || die "no ext[234] partition found on $QCOW2"
    MNT=$(mktemp -d /tmp/iseimg.XXXX)
    sudo mount -o ro,noload "$PART" "$MNT" || sudo mount -o ro "$PART" "$MNT" || die "mount $PART failed"
    SRC=$MNT; info "mounted $PART at $MNT (read-only)"
  fi
  sudo test -d "$SRC/opt/Xilinx/14.7" || die "$SRC has no /opt/Xilinx/14.7"
  copy_from() { sudo tar -C "$SRC" -cf - "$1" | tar -C "$2" -xf -; }   # read-only on the source side
  log "Copying /opt/Xilinx and /opt/intelFPGA (~36 GB)"
  mkdir -p "$ISE_DIR/opt"
  for t in opt/Xilinx opt/intelFPGA; do
    rm -rf "${ISE_DIR:?}/$t"; copy_from "$t" "$ISE_DIR"; info "/$t: $(find "$ISE_DIR/$t" | wc -l) entries"
  done
  log "Copying ise dotfiles (.Xilinx, .bash_profile, .bashrc)"
  mkdir -p "$ISE_DIR/home"
  for p in home/ise/.Xilinx home/ise/.bash_profile home/ise/.bashrc; do
    if sudo test -e "$SRC/$p"; then copy_from "$p" "$ISE_DIR/home"; else info "missing in VM: /$p"; fi
  done
  sudo chown -R "$(id -u):$(id -g)" "$ISE_DIR/opt" "$ISE_DIR/home"
  date -Is > "$ISE_DIR/.extract-done"
  (cleanup); MNT=""; NBD=""
fi
[ -d "$ISE_DIR/home/home/ise" ] || die "$ISE_DIR/home/home/ise (VM dotfiles) missing"

# ---------- 3. build context ----------
log "Assembling build context"
CTX=$(mktemp -d /tmp/ise-ctx.XXXX)
cp -a "$HERE/Dockerfile" "$HERE/impact" "$HERE/yum.repos.d" "$HERE/rpm-gpg" \
      "$HERE/vm-small.pkgs" "$HERE/yum.pkgs.txt" "$HERE/vm-rpm-qa.pkgs" "$CTX/"
cp -a "$ISE_DIR/home/home/ise" "$CTX/home"
USB_SRC=${USB_DRIVER_CACHE:-$ISE_DIR/src/xilinx-usb-driver}
if ! git -C "$USB_SRC" cat-file -e "$USB_DRIVER_REV^{commit}" 2>/dev/null; then
  info "fetching usb-driver source from $USB_DRIVER_REPO"
  rm -rf "$USB_SRC"; mkdir -p "$(dirname "$USB_SRC")"
  git clone -q "$USB_DRIVER_REPO" "$USB_SRC"
fi
mkdir -p "$CTX/usb-driver"
git -C "$USB_SRC" archive "$USB_DRIVER_REV" | tar -C "$CTX/usb-driver" -xf -
FX_TGZ=$ISE_DIR/src/${FXLOAD_URL##*/}
if ! echo "$FXLOAD_SHA256  $FX_TGZ" | sha256sum -c --status 2>/dev/null; then
  info "fetching fxload source from $FXLOAD_URL"
  mkdir -p "$ISE_DIR/src"; curl -fsSL -o "$FX_TGZ" "$FXLOAD_URL"
  echo "$FXLOAD_SHA256  $FX_TGZ" | sha256sum -c --status || die "fxload source checksum mismatch: $FX_TGZ"
fi
mkdir -p "$CTX/fxload"; tar -C "$CTX/fxload" --strip-components=1 -xzf "$FX_TGZ"
info "usb-driver @ ${USB_DRIVER_REV:0:12}, fxload 2008_10_13; context: $CTX"

# ---------- 4. build ----------
log "Building image $IMAGE"
"${DOCKER[@]}" build ${NO_CACHE:+--no-cache} --build-arg ISE_UID="$(id -u)" --build-arg ISE_GID="$(id -g)" -t "$IMAGE" "$CTX"

# ---------- 5. smoke test ----------
if [ -z "${SKIP_SMOKE:-}" ]; then
  log "Smoke test"
  DISPLAY= IMAGE=$IMAGE ISE_DIR=$ISE_DIR REPO=$REPO "$HERE/run.sh" bash -lc '
    set -e
    xst -help >/dev/null 2>&1 || { echo "xst failed"; exit 1; }; echo "xst: $(which xst)"
    echo "impact wrapper: $(which impact)"; ldd /usr/local/lib/libusb-driver.so | grep -q "not found" && exit 1
    vsim -version
    mips64-linux-gnu-gcc --version | head -1
    echo "fonts: $(fc-list | wc -l)"; /sbin/fxload -V 2>&1 | head -1; test -x /sbin/fxload' </dev/null || die "smoke test failed"
  if [ -n "${SMOKE_FULL:-}" ]; then
    P=/home/ise/shared/cs150
    "$HERE/run.sh" bash -lc "cd $P/software/gios && make && cd $P/software/proj_app6 && make fresh" </dev/null || die "proj_app6 build failed"
    "$HERE/run.sh" bash -lc "cd $P/hardware/sim && make" </dev/null || die "hardware/sim failed"
  fi
  info "smoke test passed"
fi
log "Done. Shell: $HERE/run.sh    GUI: $HERE/run.sh bash -lc ise   (ISE_DIR=$ISE_DIR IMAGE=$IMAGE)"
