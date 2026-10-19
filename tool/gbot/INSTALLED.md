# Box install inventory (cdr4eelz CS150 box)

Generated 2026-10-18 (PDT) from `/var/log/apt/history.log` (only one log; no rotated
`.gz` files exist yet), `apt-mark showmanual`, `/etc/apt/sources.list.d`,
`/usr/share/keyrings`, `~/.bashrc`, `~/.grok`, `~/.config/gh`, `/usr/local`.
Reinstall script draft: `tool/gbot/setup-box.sh` in this directory.

Box: Debian 13 trixie, external kernel `6.12.94+` (cmdline has `nomodule`,
`kernel.modules_disabled=1`), init = tini (no systemd), user `box` with passwordless sudo.

> **2026-10-18:** VirtualBox was removed from `setup-box.sh`. It installs, but its kernel driver can never load on this box, so VMs run under QEMU/KVM instead. The VirtualBox notes below are kept as history.

## 0. Stock box image (not ours, for reference)
Installed 2026-10-17 15:04-15:08 by the image build (no `Requested-By`): bash bubblewrap
ca-certificates curl ffmpeg git iproute2 jq nodejs node-corepack libssl-dev patch
poppler-utils procps psmisc python3 python3-pip python3-venv novnc **ripgrep** rustc cargo
sudo **tmux** unzip wget websockify x11vnc x11-utils x11-xserver-utils xauth libxdo3 xvfb
dbus-x11 dconf-cli xfwm4 picom plank hsetroot thunar xfce4-terminal fonts/themes, xdotool
(custom .deb), google-chrome-stable (+ `/etc/apt/sources.list.d/google-chrome.sources`,
`/usr/share/keyrings/google-chrome.gpg`), xz-utils, libreoffice-writer/calc/impress.
Also stock: everything in `/usr/local/bin` (box-*, sand-*, bun, go, uv, npm, playwright...)
**including `gh` 2.102.0** (`/usr/local/bin/gh`, mtime 2026-10-17 08:06, not a dpkg package).
=> ripgrep, tmux and gh are already present on a fresh box; the script still lists them (harmless).

## 1. Apt repositories + keys we added
| File | Line | Key |
|---|---|---|
| `/etc/apt/sources.list.d/texus-raylib.list` | `deb [signed-by=/usr/share/keyrings/texus-raylib.gpg] https://ppa.launchpadcontent.net/texus/raylib/ubuntu noble main` | `/usr/share/keyrings/texus-raylib.gpg`, fpr `D91696CDE57C6F73D0F9D36C2C25A13B4164E492` |
| `/etc/apt/sources.list.d/virtualbox.list` | `deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib` | `/usr/share/keyrings/oracle-virtualbox-2016.gpg`, fpr `B9F8D658297AF3EFC18D5CDFA2F683C52980AECF` (matches Oracle's published key) |

```bash
# raylib PPA
curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xD91696CDE57C6F73D0F9D36C2C25A13B4164E492' \
  | sudo gpg --dearmor -o /usr/share/keyrings/texus-raylib.gpg
echo 'deb [signed-by=/usr/share/keyrings/texus-raylib.gpg] https://ppa.launchpadcontent.net/texus/raylib/ubuntu noble main' \
  | sudo tee /etc/apt/sources.list.d/texus-raylib.list
# VirtualBox (exact commands run 2026-10-18 21:17 PDT; trixie suite IS published)
wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
  | sudo gpg --yes --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib" \
  | sudo tee /etc/apt/sources.list.d/virtualbox.list
sudo apt-get update
```

## 2. Packages we installed (all `Requested-By: box`), in order
| When (PDT) | Command | Purpose | Status |
|---|---|---|---|
| 10-17 17:44 | `apt-get install -y gcc-mips-linux-gnu binutils-mips-linux-gnu` | CS150 MIPS cross toolchain (GCC 14.2; `gcc-12-mips-linux-gnu` not in trixie) | requested |
| 10-17 17:48 | `apt-get install -y make` | build | requested |
| 10-17 17:57 | `apt-get install -y pkg-config cmake libasound2-dev libx11-dev libxrandr-dev libxi-dev libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev libwayland-dev libxkbcommon-dev` | deps for raylib 5.5 source build | assistant-chosen deps (marked manual) |
| 10-17 17:58 | `apt-get install -y g++` | raylib source build / C++ | requested-ish (assistant for raylib) |
| 10-17 18:09 | `apt-get install -y libraylib6-dev` (6.2.0+noble, from texus PPA) | raylib (vizard project) | requested |
| 10-17 19:16 | `apt install less screen tmux bash-completion ncurses-term screenie iselect bat` | terminal tools (user typed this interactively) | requested |
| 10-18 07:49 | `apt-get install -y iverilog` (Icarus Verilog 12.0) | HDL sim | requested |
| 10-18 16:26 | `apt-get install -y docker.io qemu-system-x86 qemu-utils` | containers / KVM VMs | requested |
| 10-18 21:18 | `apt-get install -y virtualbox-7.2` (7.2.20r175154) | VirtualBox | requested |

`apt-mark showmanual` (84 pkgs) = stock image list above + exactly the packages in this table
(no other manual packages). Everything else (e.g. docker-cli, containerd, iptables, runc,
qemu-system-modules-*, ovmf, Qt6 libs) is `automatic`.

**Side effect of the VirtualBox install (recommends):** it pulled in 75 packages including
`linux-headers-amd64`, `linux-headers-6.12.113+deb13-amd64`, `linux-image-6.12.113+deb13-amd64`,
`linux-kbuild-6.12.113+deb13`, `initramfs-tools`, `dracut-install`, `kmod`, `udev`, `busybox`,
`zathura`, Qt6. The Debian kernel image/headers are useless here (box boots an external kernel;
they do NOT match `6.12.94+`). Left in place. To remove (optional):
`sudo apt-get purge linux-image-6.12.113+deb13-amd64 linux-headers-amd64 linux-headers-6.12.113+deb13-amd64 && sudo apt-get autoremove`
The setup script uses `--no-install-recommends` for VirtualBox to avoid this.

Uncertainty: which of the raylib `-dev` deps / g++ the user explicitly asked for vs. the
assistant chose is inferred from timing; all are marked manual by apt.

## 3. Non-apt installs
| Item | How | Notes |
|---|---|---|
| Grok Build CLI 1.0.62 | `curl -fsSL https://x.ai/cli/install.sh \| bash` | installs to `~/.grok/` (`~/.grok/bin/grok` -> `~/.grok/downloads/grok-linux-x86_64`), appends to `~/.bashrc` lines 115-118: `# >>> grok installer >>>` / `export PATH="$HOME/.grok/bin:$PATH"` / completions source / `# <<< grok installer <<<` |
| gh CLI 2.102.0 | stock in box image (`/usr/local/bin/gh`) | config in `~/.config/gh/` (created 10-17 15:18) |
| raylib 5.5 source build | `/workspace/raylib` (source still present), cmake install to `/usr/local` | **removed** from /usr/local later; only an **empty leftover dir `/usr/local/lib/cmake/raylib/`** remains (safe to `sudo rmdir`) |
| pip --user / npm -g | none | `~/.local` does not exist; `/usr/local/lib/node_modules` is stock |

## 4. Config / environment
- `~/.bashrc`: only change is the grok installer block (above).
- CS150 helper scripts: `export PATH=/workspace/cs150-1245/bin:$PATH` used per-session for
  `bin2mif`, `bin2coe`, `bin2mem`, ... **temporary, not persisted** in any rc file.
- Docker: no systemd, so the daemon is started manually: `sudo dockerd > /tmp/dockerd.log 2>&1 &`.
  `box` is not in the `docker` group (use sudo) and not in `kvm` (`/dev/kvm` is root:kvm 0660;
  QEMU needs sudo or `sudo usermod -aG kvm box` + new login).
- VirtualBox created group `vboxusers` (box not a member) and `~/.config/VirtualBox/`.
  Test VM was created and deleted; `~/VirtualBox VMs/` is empty.

## 5. Manual steps (not scriptable)
1. `gh auth login` - device-code login as **cdr4eelz**.
2. `grok login --device-auth` - device-code login.
3. Start dockerd each session (see above).

## 6. VirtualBox status on this box
- Userland installed and works: `VBoxManage --version` -> `7.2.20r175154`; `VBoxManage list hostinfo` works.
- **vboxdrv cannot be built or loaded - hard blocker in the box's kernel, not fixable from inside:**
  - Running kernel `6.12.94+` is a custom build (`root@0a07c1601064`, Oct 16 2026); no
    `/lib/modules/6.12.94+` and no matching `linux-headers-*` package exists
    (closest Debian pkg is `6.12.94+deb13-amd64`, different ABI / not this build).
  - Kernel cmdline contains `nomodule`, and `/proc/sys/kernel/modules_disabled = 1`
    (one-way latch; writing 0 -> `Invalid argument`). `/proc/modules` is empty (all drivers built-in).
  - Proven: even with full root caps (`sudo` CapEff `000001ffffffffff`), `sudo insmod .../dummy.ko.xz`
    -> `Operation not permitted`.
  - `sudo /sbin/vboxconfig` -> "This system is currently not set up to build kernel modules".
  - Test VM: `createvm`/`modifyvm` OK, `startvm --type headless` -> "terminated unexpectedly
    during startup with exit code 1 (NS_ERROR_FAILURE)"; VM unregistered + deleted.
- KVM is available: `CONFIG_KVM_INTEL=y`, nested, `ept=Y`, `unrestricted_guest=Y`, XSAVE present.

### Realistic options for running the Oracle Linux 6 / ISE / ModelSim VM
1. **Convert the VM and run it under QEMU/KVM (already installed, official Debian pkgs)** - recommended.
   Unpack the `.ova` (`tar xf vm.ova`), `qemu-img convert -O qcow2 disk.vmdk ol6.qcow2`, then e.g.
   `sudo qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 4 -drive file=ol6.qcow2,if=ide -nic user,model=e1000 -vnc :1`
   (OL6 lacks newer virtio drivers in some images, so IDE/e1000 is safest). VirtualBox Guest Additions won't work; that's fine.
2. **Unofficial Cyberus `virtualbox-kvm` backend** (github.com/cyberus-technology/virtualbox-kvm) - replaces vboxdrv
   with /dev/kvm. NOT installed. Would require building VirtualBox from source with their patch; latest patch
   `dev-20260201` targets VirtualBox 7.2.6 (AUR adapts it to 7.2.14; nothing for 7.2.20), only regular NAT
   networking (driverless mode), Intel host only. Feasible but a substantial, unofficial source build.
3. Official VirtualBox 7.2.2+ "uses KVM APIs on kernel >= 6.16 to acquire VT-x" - that still needs vboxdrv,
   and this kernel is 6.12, so no help.
4. Run VirtualBox somewhere with a normal kernel (the user's own PC / a cloud VM with a stock distro kernel).
5. Ask the box provider for a kernel without `nomodule`/`modules_disabled` (out of our control).
