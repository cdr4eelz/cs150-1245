#!/usr/bin/env bash
# Run the Xilinx ISE 14.7 + ModelSim container.  Usage: run.sh [command...]   (default: login shell)
#   run.sh bash -lc 'cd shared/cs150/hardware/sim && make'
#   run.sh bash -lc coregen        # GUI: needs DISPLAY (local X or ssh -X)
# Env: ISE_DIR, REPO, IMAGE (see common.sh), DOCKER_ARGS (extra docker run args)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
[ -d "$ISE_DIR/opt/Xilinx" ] || { echo "run.sh: $ISE_DIR/opt/Xilinx not found (set ISE_DIR)" >&2; exit 1; }
[ $# -eq 0 ] && set -- bash -l
args=(--rm --mac-address 08:00:27:68:C9:35 --hostname localhost.localdomain --security-opt seccomp=unconfined
      -v "$ISE_DIR/opt/Xilinx:/opt/Xilinx:ro" -v "$ISE_DIR/opt/intelFPGA:/opt/intelFPGA:ro"
      -v "$REPO:/home/ise/shared/cs150")
if [ -t 0 ] && [ -t 1 ]; then args+=(-it); fi
# USB (Platform Cable USB, via the impact wrapper) and the board's serial port
if [ -d /dev/bus/usb ]; then args+=(-v /dev/bus/usb:/dev/bus/usb --device-cgroup-rule 'c 189:* rmw'); fi
for t in /dev/ttyUSB*; do if [ -e "$t" ]; then args+=(--device "$t"); fi; done
if getent group dialout >/dev/null; then args+=(--group-add "$(getent group dialout | cut -d: -f3)"); fi

# X11. The VM's ~/.bashrc pins DISPLAY=:0, so the host display always appears as :0 in the container.
# Local display (:N) -> bind its socket as X0. ssh -X display (localhost:N) -> relay it into a socket with
# socat, because the container is on the bridge network (it can't use --network host: the ISE license is
# locked to the --mac-address above). Either way the container gets a wildcard xauth cookie for :0.
TMPX=""; RELAY=""
cleanup() { [ -n "$RELAY" ] && kill "$RELAY" 2>/dev/null; [ -n "$TMPX" ] && rm -rf "$TMPX"; true; }
trap cleanup EXIT
if [ -n "${DISPLAY:-}" ]; then
  TMPX=$(mktemp -d /tmp/ise-x11.XXXX); chmod 755 "$TMPX"
  num=${DISPLAY#*:}; num=${num%%.*}
  case "$DISPLAY" in
    :*|unix:*) args+=(-v "/tmp/.X11-unix/X$num:/tmp/.X11-unix/X0") ;;
    *) command -v socat >/dev/null || { echo "run.sh: install socat for ssh -X displays" >&2; exit 1; }
       mkdir -p "$TMPX/sock"; chmod 1777 "$TMPX/sock"
       socat "UNIX-LISTEN:$TMPX/sock/X0,fork,mode=777" "TCP:${DISPLAY%%:*}:$((6000+num))" & RELAY=$!
       sleep 0.3; args+=(-v "$TMPX/sock:/tmp/.X11-unix") ;;
  esac
  touch "$TMPX/Xauthority"
  cookie=$(xauth list "$DISPLAY" 2>/dev/null | awk '$2 == "MIT-MAGIC-COOKIE-1" {print $3; exit}' || true)
  if [ -n "$cookie" ]; then
    xauth -q -f "$TMPX/xa.tmp" add :0 MIT-MAGIC-COOKIE-1 "$cookie" 2>/dev/null
    xauth -q -f "$TMPX/xa.tmp" nlist | sed -e 's/^..../ffff/' | xauth -q -f "$TMPX/Xauthority" nmerge -
  fi
  chmod 644 "$TMPX/Xauthority"
  args+=(-e DISPLAY=:0 -e XAUTHORITY=/tmp/.Xauthority -v "$TMPX/Xauthority:/tmp/.Xauthority:ro")
fi
# shellcheck disable=SC2206
args+=(${DOCKER_ARGS:-})
"${DOCKER[@]}" run "${args[@]}" "$IMAGE" "$@"
