# Xilinx ISE 14.7 + ModelSim ASE build environment, matching the Oracle Linux 6 ISE VM.
# Do not run `docker build` here directly: setup-ise-docker.sh assembles the build context
# (this directory + the pinned usb-driver source + the VM's ~ise dotfiles) and builds it.
# The ISE/ModelSim trees (/opt/Xilinx, /opt/intelFPGA) are NOT in the image; run.sh mounts them read-only.

# ---- stage 1: iMPACT USB helpers built from source ----
# libusb-driver.so: windrvr6 emulator for iMPACT (Michael Gernoth's usb-driver, MIT-style license)
# fxload: EZ-USB firmware loader for the Platform Cable USB (2008_10_13, the VM's version; GPL-2; not in OL6/EPEL6 repos)
FROM oraclelinux:6 AS usbdrv
RUN yum -y install gcc make libusb-devel
COPY usb-driver/ /src/usb-driver/
RUN cd /src/usb-driver && make libusb-driver.so
COPY fxload/ /src/fxload/
RUN cd /src/fxload && make fxload

# ---- stage 2: the ISE runtime image ----
FROM oraclelinux:6
# VM's yum repo files and GPG keys. The yum cache and repo files are deliberately kept
# (no `yum clean`), so the image behaves like the VM when packages are added by hand.
COPY yum.repos.d/ /etc/yum.repos.d/
COPY rpm-gpg/ /etc/pki/rpm-gpg/
COPY vm-small.pkgs yum.pkgs.txt vm-rpm-qa.pkgs /root/
# EPEL 6 is end-of-life: point the image's epel repo at the Fedora archive (the repo file is edited, not removed)
RUN sed -i -e 's|^mirrorlist=|#mirrorlist=|' -e 's|^#baseurl=http://download.fedoraproject.org/pub/epel/6/|baseurl=https://archives.fedoraproject.org/pub/archive/epel/6/|' /etc/yum.repos.d/epel.repo
# MIPS cross toolchain, libmpc and python34 come from EPEL packages (same versions as the VM)
RUN yum -y install gcc-mips64-linux-gnu binutils-mips64-linux-gnu cross-gcc-common cross-binutils-common libmpc python34 python34-libs
# ISE runtime libs (64- and 32-bit), X11 + fonts for the GUIs (ise, coregen), USB for iMPACT
RUN yum -y install make git perl which tar gzip bzip2 findutils procps file diffutils sudo \
      gmp mpfr libmpc zlib glibc.i686 libstdc++.i686 ncurses-libs.i686 zlib.i686 \
      libX11 libXext libXft libXrender libXi libXtst libXrandr libSM libICE fontconfig freetype \
      libX11.i686 libXext.i686 libXft.i686 libXrender.i686 libSM.i686 libICE.i686 fontconfig.i686 freetype.i686 libXau.i686 expat.i686 \
      libpng libjpeg-turbo glib2 libuuid libusb libusb1 usbutils xorg-x11-utils xorg-x11-xauth \
      dejavu-fonts-common dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts \
      liberation-fonts-common liberation-mono-fonts liberation-sans-fonts liberation-serif-fonts \
      xorg-x11-fonts-Type1 xorg-x11-fonts-misc xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-fonts-ISO8859-1-100dpi \
      urw-fonts ghostscript-fonts libXfont \
 && fc-cache -f \
 && ln -sf /lib64/libusb-1.0.so.0 /usr/lib64/libusb.so
# Match the VM's userland: extra tools from the VM (kernel packages skipped; unavailable names are skipped)
RUN yum -y --skip-broken install $(grep -v '^kernel' /root/vm-small.pkgs) || true
COPY --from=usbdrv /src/usb-driver/libusb-driver.so /usr/local/lib/libusb-driver.so
COPY --from=usbdrv /src/fxload/fxload /sbin/fxload
COPY --from=usbdrv /src/fxload/a3load.hex /usr/share/usb/a3load.hex
ARG ISE_UID=1000
ARG ISE_GID=1000
RUN groupadd -g $ISE_GID ise && useradd -u $ISE_UID -g $ISE_GID -G wheel ise && echo 'ise ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ise
# ~ise dotfiles (.bash_profile, .bashrc, .Xilinx) copied from the VM by setup-ise-docker.sh (never committed)
COPY --chown=$ISE_UID:$ISE_GID home/ /home/ise/
# impact wrapper (~/bin precedes the ISE bin dir in PATH): loads cable firmware with fxload, preloads libusb-driver.so
COPY --chown=$ISE_UID:$ISE_GID impact /home/ise/bin/impact
RUN chmod 755 /home/ise/bin/impact && mkdir -p /home/ise/shared /scratch && chmod 1777 /scratch && chown -R $ISE_UID:$ISE_GID /home/ise
USER ise
WORKDIR /home/ise
CMD ["bash","-l"]
