# Sourced by setup-ise-docker.sh and run.sh. Shared defaults; every value can be overridden from the environment.
ISE_DOCKER_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Image tag
IMAGE=${IMAGE:-ise14.7:ol6}
# CS150 checkout mounted at /home/ise/shared/cs150 (default: the repo this script lives in)
REPO=${REPO:-$(cd "$ISE_DOCKER_HERE/../.." && pwd)}
# ISE_DIR: local, never-committed dir holding the tools copied out of the VM:
#   opt/Xilinx, opt/intelFPGA, home/home/ise/{.bash_profile,.bashrc,.Xilinx}
# Default: $ISE_DOCKER_DIR, else the first of ~/ise-docker, /workspace/ise-docker that has opt/Xilinx/14.7
if [ -z "${ISE_DIR:-}" ]; then
  ISE_DIR=${ISE_DOCKER_DIR:-}
  if [ -z "$ISE_DIR" ]; then
    for c in "$HOME/ise-docker" /workspace/ise-docker; do
      if [ -d "$c/opt/Xilinx/14.7" ]; then ISE_DIR=$c; break; fi
    done
  fi
  ISE_DIR=${ISE_DIR:-$HOME/ise-docker}
fi
# Use plain docker if this user may, otherwise sudo docker
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi
