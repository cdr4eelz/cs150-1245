# Xilinx ISE 14.7 + ModelSim in Docker (Oracle Linux 6)

This replaces the QEMU ISE VM for builds, simulation, the GUIs (ise, coregen) and iMPACT. The image matches
the VM: Oracle Linux 6 userland, the VM's yum repo files and GPG keys, its extra packages, and its `~ise`
dotfiles. The yum cache and repo files stay in the image, so packages can be added by hand later the way
they are in the VM. The ~36 GB of tools (`/opt/Xilinx`, `/opt/intelFPGA`) are not in the image and not in
git. `run.sh` mounts them read-only from a local directory (`ISE_DIR`).

The procedure is the same on Ubuntu 24.04 (UBU24) and Debian 13 (the DEB13 box).

## Files

| file | purpose |
|---|---|
| `Dockerfile` | two stages: builds `libusb-driver.so` and `fxload` from source, then the OL6 runtime image |
| `setup-ise-docker.sh` | host packages, copies tools out of the VM disk (read-only), assembles the build context, builds, smoke test |
| `run.sh` | runs the container: tool mounts, repo mount, USB, serial, X11 |
| `common.sh` | shared defaults (`ISE_DIR`, `IMAGE`, `REPO`, docker vs sudo docker) |
| `impact` | iMPACT wrapper installed as `~/bin/impact`: fxload cable firmware, then `LD_PRELOAD=libusb-driver.so` |
| `yum.repos.d/`, `rpm-gpg/` | the VM's `/etc/yum.repos.d` and `/etc/pki/rpm-gpg` (public keys only) |
| `vm-small.pkgs` | extra tools from the VM installed in the image |
| `vm-rpm-qa.pkgs` | the VM's full package list (`name.arch`, from `rpm -qa`), for reference |
| `yum.pkgs.txt` | `yum list installed` taken with the VM's repo config, for reference (versions and source repos) |

## Prerequisites

- Ubuntu 24.04 or Debian 13 on x86_64, with sudo. The script installs `docker.io`, `git`, `socat` and `xauth`
  if they are missing, plus `qemu-utils` if it has to copy the tools out of the VM disk.
- About 40 GB free for `ISE_DIR`.
- The ISE 14.7 VM disk image (`ise14.7.qcow2`, Oracle Linux 6, user `ise`, uid 1000). The tools come from it:
  - `/opt/Xilinx` (ISE 14.7) → `$ISE_DIR/opt/Xilinx`
  - `/opt/intelFPGA` (ModelSim ASE 10.1d) → `$ISE_DIR/opt/intelFPGA`
  - `/home/ise/{.Xilinx,.bash_profile,.bashrc}` (license and tool environment) → `$ISE_DIR/home/home/ise/`

  The script attaches the qcow2 read-only (`qemu-nbd --read-only`, then `mount -o ro,noload`) and only reads
  from it. Never boot-and-modify the VM for this, and never write into the VM's shared directory. If the VM root
  filesystem is already mounted read-only somewhere (for example `/tmp/vmfs`), pass `VM_ROOT=/tmp/vmfs` instead.
  An `ISE_DIR` that already has `opt/Xilinx/14.7` is reused as is.
- Nothing from `ISE_DIR` (Xilinx binaries, license files) goes into git. Do not commit any VM password or other secret.

## Build

    tool/ise-docker/setup-ise-docker.sh                          # defaults
    ISE_DIR=/workspace/ise-docker IMAGE=ise14.7:ol6 tool/ise-docker/setup-ise-docker.sh
    QCOW2=~/Desktop/ise14.7.qcow2 ISE_DIR=~/ise-docker tool/ise-docker/setup-ise-docker.sh

Settings (all are environment variables):

| variable | default |
|---|---|
| `ISE_DIR` | `$ISE_DOCKER_DIR`, else the first of `~/ise-docker` and `/workspace/ise-docker` that has `opt/Xilinx/14.7`, else `~/ise-docker` |
| `IMAGE` | `ise14.7:ol6` |
| `REPO` | this checkout (mounted at `/home/ise/shared/cs150`) |
| `QCOW2` / `VM_ROOT` | `~/Desktop/ise14.7.qcow2` / unset |
| `SKIP_SMOKE=1` | skip the smoke test |
| `SMOKE_FULL=1` | also build `software/proj_app6` and run `hardware/sim` (writes build outputs into `REPO`) |
| `FORCE_EXTRACT=1`, `NO_CACHE=1` | re-copy the tools; build without the docker cache |

The image user `ise` gets your uid and gid, so files written in the mounted repo belong to you.
Re-running is cheap: extraction is skipped and docker reuses cached layers. To try a change without
replacing a working image, build under another tag (`IMAGE=ise14.7:ol6-test`).

The smoke test runs `xst -help`, checks the `impact` wrapper and `libusb-driver.so`, `vsim -version`, the MIPS
cross gcc, and the font count. It takes a few seconds.

## Run

    tool/ise-docker/run.sh                                   # login shell, repo at ~/shared/cs150
    tool/ise-docker/run.sh bash -lc 'cd shared/cs150/hardware/sim && make'

Build order for the project: `software/` first, then `core_ip`, then `hardware` (it needs the core_ip output).
Coregen rewrites the dates in `.xco` files. After a build, revert that churn with `git checkout -- '*.xco'`.

Container settings that matter:
- The license is node-locked, so the container runs with `--mac-address 08:00:27:68:C9:35` and `--hostname localhost.localdomain`.
  For that reason it stays on the bridge network (`--network host` would drop the MAC).
- `--security-opt seccomp=unconfined` is needed by the old 32-bit tools.
- `/scratch` exists and is writable, because the project scripts expect it.
- Extra `docker run` arguments go in `DOCKER_ARGS`.

## GUI: ise, coregen, ModelSim (X11)

    tool/ise-docker/run.sh bash -lc ise
    tool/ise-docker/run.sh bash -lc coregen

- Local desktop (`DISPLAY=:0`): `run.sh` shares `/tmp/.X11-unix`.
- Over SSH (`ssh -X` or `ssh -Y`, `DISPLAY=localhost:10`): `run.sh` relays the forwarded display into a socket with `socat`,
  because the container cannot reach the host's localhost.
- In both cases it hands the container a wildcard xauth cookie (`xauth nlist | sed 's/^..../ffff/'`) in a temporary file.
- Fonts: the image carries DejaVu, Liberation, URW/Ghostscript and the core X bitmap fonts (misc, 75dpi, 100dpi, Type1),
  plus `fc-cache`. Coregen and the ISE GUI need these to draw text.

## iMPACT with the Platform Cable USB (no windrvr6)

    tool/ise-docker/run.sh bash -lc impact          # or: impact -batch cmds.txt

- `run.sh` mounts `/dev/bus/usb` and allows USB character devices (`--device-cgroup-rule 'c 189:* rmw'`). It also passes
  `/dev/ttyUSB*` and the `dialout` group for the board UART.
- `~/bin/impact` (ahead of the ISE bin directory in `PATH`) finds any Xilinx cable that has no firmware yet
  (`03fd:0007/0009/000d/000f/0013/0015`) and loads the matching `xusb*.hex` from the ISE tree with `fxload`. The cable then
  re-enumerates as `03fd:0008`. After that the wrapper runs the real impact with `LD_PRELOAD=/usr/local/lib/libusb-driver.so`.
  No kernel module and no host udev rule are needed.
- `libusb-driver.so` is a userspace emulation of the Jungo windrvr6 API on top of libusb-0.1. It is Michael Gernoth's usb-driver
  (MIT-style license; origin `git://git.zerfleddert.de/usb-driver`), built from source in the first Docker stage. The
  setup script fetches the GitHub mirror `JohnDMcMaster/xilinx-usb-driver`, pinned to commit `50cb89f`
  (override with `USB_DRIVER_REPO` / `USB_DRIVER_REV`). The binary is not committed.
- `fxload` is not in the OL6 or EPEL 6 repos, so it is also built from source in the first stage: version 2008_10_13 (the VM's
  version, GPL-2), from the Debian source tarball checked against a pinned sha256 (`FXLOAD_URL` to override).
- `XIL_IMPACT_USE_LIBUSB` is not set; the shim replaces it.

## Troubleshooting

- **`permission denied` on the docker socket**: the scripts fall back to `sudo docker`. To drop sudo, add yourself to the `docker` group and log in again.
- **License errors / "no valid license"**: check that the container still has the MAC `08:00:27:68:C9:35` (do not add `--network host`), and that `$ISE_DIR/home/home/ise/.Xilinx` was copied.
- **Old tools crash or hang at start**: keep `--security-opt seccomp=unconfined`.
- **GUI: `cannot open display`**: check `echo $DISPLAY` on the host. Over SSH, make sure X11 forwarding is on and `socat` and `xauth` are installed. Locally, try `xhost +SI:localuser:$(id -un)`.
- **GUI: blank or missing text in coregen**: run `fc-list | wc -l` inside the container (about 90 in the current image; 0 or a handful means fonts are missing). Rebuild the image if the font packages are missing.
- **iMPACT finds no cable**: run `lsusb | grep 03fd` on the host. `0008` means firmware is loaded; another id means the wrapper should load it, so look at its message. Make sure `/dev/bus/usb` is mounted (it is with `run.sh`). If a host udev rule or another program holds the cable, unplug it and replug it.
- **`yum` fails while building**: the image uses the VM's repo files. EPEL 6 is redirected to `archives.fedoraproject.org` because EPEL 6 is end of life. Oracle's OL6 repos are still online. A dead third-party repo can be skipped for one command with `--setopt=<repo>.skip_if_unavailable=1`.
- **Smoke test fails at `xst`**: `ISE_DIR/opt/Xilinx/14.7/ISE_DS/settings64.sh` must exist, and `.bash_profile` must source it. Check `run.sh bash -lc 'echo $PATH'`.

## Why not the VM

On the DEB13 box, KVM crashes the guest, so the VM runs under TCG, which is very slow:

| step | container | VM (TCG) |
|---|---|---|
| proj_app6 software | 0.25 s | 3.7 s |
| simulation | 4.6 s | 1 m 42 s |
| hardware (synth/PAR) | 5 m 10 s | > 18 min |

## macOS / Apple Silicon (future, untested)

Andrew Owen's [Running Xilinx ISE on an M1 Mac](https://andrewowen.net/blog/running-xilinx-ise-on-an-m1-mac/) (2022) runs ISE 14.7
under x86_64 emulation. He uses a UTM (QEMU) VM with Linux Mint 20.1 Xfce, which is light enough on the GUI, and installs ISE WebPack
there. He notes that Rosetta JIT support for UTM in macOS 13 should make this much faster. We have not tried it. The same approach
should apply to this image: run the `linux/amd64` image under Docker Desktop or Colima with Rosetta or QEMU emulation, then feed it
`ISE_DIR` and X11 through XQuartz.
