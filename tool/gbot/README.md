# tool/gbot

This folder holds setup notes for **E**, the Grok Bot assistant that works on this repo from its own Linux computer (the "box", running Debian 13). Nothing in the CS150 build depends on it.

- **`INSTALLED.md`** lists everything installed or configured on the box beyond the stock image: packages, apt repos and keys, the Grok Build CLI, and the logins that have to be done by hand. It also records known limits, for example that VirtualBox can't load its kernel driver there, so VMs run under QEMU/KVM instead.
- **`setup-box.sh`** reinstalls everything after the box is moved to a fresh instance. It is safe to run more than once. Use `--no-docker` (skips Docker and QEMU/KVM) or `--no-raylib` to skip those parts. VirtualBox is deliberately left out. At the end it prints the manual steps (`gh auth login`, `grok login --device-auth`, starting `dockerd`).

When something new is installed on the box, update both files.
