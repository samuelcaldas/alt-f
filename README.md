# Alt-F: Alternative Firmware for D-Link ARM NAS

> **Free, open-source alternative firmware for D-Link DNS-320, DNS-320L, DNS-321, DNS-323, DNS-325, DNS-327L, and DNR-322L Network Attached Storage devices.**

[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](COPYING)
[![Architecture: ARMv5 / ARMv7](https://img.shields.io/badge/Architecture-ARMv5%20%7C%20ARMv7-orange.svg)](local/)
[![Kernel: Linux 4.14 LTS](https://img.shields.io/badge/Kernel-Linux%204.14-green.svg)](project/)
[![Documentation: GitHub Pages](https://img.shields.io/badge/Documentation-GitHub%20Pages-brightgreen.svg)](https://samuelcaldas.github.io/alt-f/)
[![SourceForge Project](https://img.shields.io/badge/SourceForge-alt--f-blue.svg)](https://sourceforge.net/projects/alt-f/)
[![Forum: Google Groups](https://img.shields.io/badge/Community-Google%20Groups-red.svg)](https://groups.google.com/group/alt-f)

Alt-F replaces the stock proprietary firmware on select D-Link Network Attached Storage (NAS) boxes with a complete, secure, and customizable Linux distribution. Built on a tailored Buildroot tree with Linux Kernel 4.14 LTS, uClibc-ng, and BusyBox, Alt-F provides enterprise-class storage capabilities, modern networking services, an extensible package manager, and a modernized web administration interface tailored to run efficiently within embedded hardware limits (e.g., 256MB RAM on Kirkwood 88F6702).

---

## Table of Contents

- [Supported Hardware](#supported-hardware)
- [Key Features](#key-features)
  - [Storage & Filesystems](#storage--filesystems)
  - [Networking & File Sharing](#networking--file-sharing)
  - [System Services & Daemons](#system-services--daemons)
  - [Modernized Web Administration Interface](#modernized-web-administration-interface)
  - [Package Management](#package-management)
- [Installation & Getting Started](#installation--getting-started)
  - [Flashing Alt-F](#flashing-alt-f)
  - [First Boot & Locating Your NAS](#first-boot--locating-your-nas)
  - [LED Diagnostics & Button Controls](#led-diagnostics--button-controls)
  - [Saving Settings Across Reboots](#saving-settings-across-reboots)
  - [Restoring / Downgrading to Stock Firmware](#restoring--downgrading-to-stock-firmware)
- [Building from Source](#building-from-source)
  - [Native Build Environment](#native-build-environment)
  - [Containerized Build with Docker (Recommended)](#containerized-build-with-docker-recommended)
  - [Flash Partition Limits](#flash-partition-limits)
- [Testing & Quality Assurance](#testing--quality-assurance)
  - [Automated UI Verification Suite](#automated-ui-verification-suite)
  - [ARMv5 Validation & Emulation](#armv5-validation--emulation)
- [Repository Structure](#repository-structure)
- [Official Resources & Documentation](#official-resources--documentation)
- [License & Acknowledgments](#license--acknowledgments)

---

## Supported Hardware

Alt-F officially supports the following hardware models and revisions:

| Model | Hardware Revision | SoC / CPU Architecture | Flash / RAM | Board Profile | Target Firmware Binary |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DNS-320** | Rev A1, A2 | Marvell Kirkwood 88F6281 (ARM926EJ-S, ARMv5TEJ @ 800MHz) | 128MB NAND / 128MB RAM | `dns325` | `Alt-F-<ver>-DNS-320-rev-Ax.bin` |
| **DNS-320** | Rev B1, B2 | Marvell Kirkwood 88F6702 (ARM926EJ-S, ARMv5TEJ @ 1.0GHz) | 128MB NAND / 128MB RAM | `dns325` | `Alt-F-<ver>-DNS-320-rev-Bx.bin` |
| **DNS-320L** | Rev A1, A2, A3 | Marvell Kirkwood 88F6702 (ARM926EJ-S, ARMv5TEJ @ 1.0GHz) | 128MB NAND / 256MB RAM | `dns325` | `Alt-F-<ver>-DNS-320L-rev-Ax.bin` |
| **DNS-321** | Rev A1, A2 | Marvell Orion 88F5182 (ARM926EJ-S, ARMv5TEJ @ 500MHz) | 8MB NOR / 64MB RAM | `dns323` | `Alt-F-<ver>-DNS-321-rev-Ax.bin` |
| **DNS-323** | Rev A1, B1, C1 | Marvell Orion 88F5181/88F5182 (ARM926EJ-S @ 500MHz) | 8MB NOR / 64MB RAM | `dns323` | `Alt-F-<ver>-DNS-323-rev-AxBxCx.bin` |
| **DNS-325** | Rev A1, A2 | Marvell Kirkwood 88F6281 (ARM926EJ-S, ARMv5TEJ @ 1.2GHz) | 128MB NAND / 256MB RAM | `dns325` | `Alt-F-<ver>-DNS-325-rev-Ax.bin` |
| **DNS-327L** | Rev A1 | Marvell Armada 370 88F6707 (ARMv7 @ 1.2GHz) | 128MB NAND / 512MB RAM | `dns327` | `Alt-F-<ver>-DNS-327L-rev-Ax.bin` |
| **DNR-322L** | Rev A1 | Marvell Kirkwood 88F6281 (Identical to DNS-320 Rev A) | 128MB NAND / 128MB RAM | `dns325` | `Alt-F-<ver>-DNR-322L-rev-Ax.bin` |
| **CH3SNAS** | Rev B1 | Conceptronic rebrand of DNS-323 Rev B1 | 8MB NOR / 64MB RAM | `dns323` | `Alt-F-<ver>-CH3SNAS.bin` |
| **DUO 35-LR** | Rev B1 | Fujitsu-Siemens rebrand of DNS-323 Rev B1 | 8MB NOR / 64MB RAM | `dns323` | `Alt-F-<ver>-DUO-35LR.bin` |

---

## Key Features

### Storage & Filesystems
- **Large Disk Support:** Supports drives up to 8TB+ with both GPT (`gptfdisk`/`sgdisk`) and legacy MBR partition tables.
- **Filesystem Diversity:** Full support for `ext2`, `ext3`, `ext4`, `Btrfs`, `VFAT/FAT32`, `exFAT`, and read/write NTFS via `ntfs-3g`.
- **Advanced Volume Management:**
  - Soft-RAID (`mdadm`): Supports Standard, JBOD, RAID0, RAID1, and RAID5 (with an external USB storage drive).
  - **Non-Destructive RAID Migration:** Convert bidirectional between standard single-disk filesystems and RAID1 without data destruction.
  - Degraded array automatic repair and hot rebuilds.
  - Logical Volume Management (`LVM2`) with volume groups, logical volumes, and snapshots.
  - Block device encryption with LUKS (`cryptsetup`).
- **Remote Filesystem Mounting:** Seamless mounting of remote CIFS/SMB and NFS exports into local storage hierarchies.

### Networking & File Sharing
- **Windows Networking:** Samba 4 (SMB2, SMB3) with Microsoft WS-Discovery daemon (`wsdd2`) for automatic network visibility in Windows 10/11 without SMBv1.
- **Unix/Linux File Sharing:** Native NFS v3/v4 server and client utilities (`nfs-utils`, `portmap`).
- **Secure File Transfers:** FTPS/FTP server (`vsftpd`), Secure Shell (`sshd` via OpenSSH and Dropbear), SFTP subsystem (`openssh-sftp`), and `rsync`.
- **Apple Filing Protocol:** Netatalk (`afpd`) for macOS Time Machine and AFP shares.

### System Services & Daemons
- **Networking Infrastructure:** Dnsmasq (integrated DHCP and local DNS server), Inadyn (dynamic DNS client for multiple providers), and Avahi (mDNS / Zeroconf / Bonjour).
- **Security & SSL:** Automated SSL certificate management, self-signed root CA generation, Let's Encrypt support, and Stunnel SSL wrapper.
- **Hardware Automation:** Temperature-guided cooling fan regulation, LED activity indicators, disk spindown timers (`hdparm`), and safe power-button shutdown/reboot controls.
- **Monitoring & Alerts:** S.M.A.R.T. disk health analysis (`smartmontools`), UPS power monitoring (Network UPS Tools - NUT, `apcupsd`), and automated email notifications (`msmtp`).
- **Media & Downloads:** MiniDLNA (UPnP/DLNA streaming), Mediatomb, Fuppes, mt-daapd, Transmission (BitTorrent), Aria2, aMule, NZBGet, and SABnzbd.
- **Web & Databases:** BusyBox `httpd`, Lighttpd, and MySQL/MariaDB.

### Modernized Web Administration Interface
The administrative interface has been modernized to eliminate legacy multi-frame navigation while preserving ultra-low resource usage:
- **Zero Heavy Resident Services:** Runs purely on BusyBox `httpd` with POSIX shell CGI pairs (`<name>.cgi` for forms, `<name>_proc.cgi` for handlers).
- **Semantic & Frame-Free:** Replaces legacy `<frameset>` with clean HTML5 landmarks, responsive layouts, and mobile-friendly viewports.
- **Sub-100 KiB Resource Budget:** Combined CSS and JavaScript footprint remains well under 100 KiB per page for fast rendering on embedded CPUs.
- **Themes & Backward Compatibility:** Modern responsive `dull` theme (default), `demo` theme, and a `classic` theme preserving the original appearance with modern frame-free navigation.
- **Full Form Integrity:** Strict preservation of all form contracts, action endpoints, multipart upload handlers, session authentication challenges, and status refresh intervals.

### Package Management
- **Flash Execution:** Root filesystem executes directly from NAND/NOR flash (SquashFS + UBIFS) to preserve RAM.
- **Alt-F Package Manager (`ipkg`):** Install, update, and remove pre-compiled packages on disk or flash storage through the web interface (`Packages -> Alt-F`).
- **Third-Party Ecosystems:** Built-in web support for configuring Entware and FFP (Fonz Fun Plug) environments.

---

## Installation & Getting Started

### Flashing Alt-F
Alt-F is distributed as a vendor-compatible `.bin` image that can be flashed directly through the D-Link stock web interface:

1. **Reboot the NAS** before starting the upgrade to ensure clean memory and filesystem state.
2. **Disable/Rename Third-Party Packages:** If FFP is installed on disk, rename the `ffp` folder to `ffp-orig`.
3. **Verify Hardware Revision:** Check the sticker on the bottom of the device to identify the exact model and revision (e.g., DNS-320L Rev A3).
4. **Flash the Image:** In the stock firmware web GUI, navigate to the Firmware Upgrade section, select the corresponding `Alt-F-<version>-<model>.bin` file, and apply the update.
5. **Clear Browser Cache:** Clear browser cache or use an incognito/private window to load the updated web interface.

> ⚠️ **Warning:** Modifying embedded firmware carries risks. Ensure uninterrupted power supply during the flashing procedure.

### First Boot & Locating Your NAS
Upon booting, Alt-F determines its IP address using the following order of precedence:
1. Kernel command-line parameters (if passed via bootloader or reload script).
2. Saved Alt-F flash settings in `/etc/settings`.
3. Vendor firmware IP settings stored in flash (if static IP was configured in stock firmware).
4. DHCP query to your local router/DHCP server.
5. Fallback link-local IP in the range `192.168.1.254` down to `192.168.1.240`.

Access the web interface by opening `http://<nas-ip>/` in a web browser.

### LED Diagnostics & Button Controls
- **Slow Heartbeat Blinking Blue Power LED:** The system is running `fsck` to check disk filesystems following an unclean shutdown. Allow disk checking to complete before interacting with the system.
- **Power Button Multi-Function Controls:**
  - Hold power button for 3 seconds $\rightarrow$ Right amber LED flashes: release to trigger a clean reboot.
  - Hold power button for 6 seconds $\rightarrow$ Left amber LED flashes: release to trigger a clean system shutdown.

### Saving Settings Across Reboots
Because Alt-F runs with an in-memory/flash root filesystem, configuration changes must be committed to non-volatile flash storage:
- Navigate to **System $\rightarrow$ Settings** in the web UI.
- Click **Save Settings** to persist configurations across reboots.
- You can also download a backup archive of your settings to your computer.

### Restoring / Downgrading to Stock Firmware
Alt-F's firmware flashing utility allows flashing official D-Link stock firmware `.bin` files directly from **System $\rightarrow$ Firmware**, providing a clean rollback path whenever needed.

---

## Building from Source

All firmware generation scripts must be executed from the root of the repository.

### Native Build Environment
Ensure build prerequisites are installed on the Linux host (`build-essential`, `bison`, `flex`, `texinfo`, `automake`, `autoconf`, `subversion`, `bc`, `cpio`, `mtd-utils`, `zlib1g-dev`, `libncurses-dev`, `libssl-dev`):

```sh
# 1. Source the board configuration (must be sourced with a leading dot)
. exports dns325 [optional_build_dir]

# 2. Build the external uClibc-ng cross-toolchain (Buildroot 2019.02.8, GCC 7.4.0)
# (Required only on first build)
./mktc.sh

# 3. Compile the kernel and all enabled packages
make >& build-dns325.log

# 4. Assemble the root filesystem images (rootfs.arm.sqall.xz, ubifs, etc.)
./mkinitramfs.sh

# 5. Package the final vendor-flashable .bin firmware images in $BINARIES
./mkfw.sh
```

### Containerized Build with Docker (Recommended)
Because modern distributions with glibc $\ge$ 2.33 removed internal definitions (`_STAT_VER`, `__xstat64`) required by legacy host build utilities (such as `fakeroot` 1.9.5), a dedicated reproducible build environment based on Ubuntu 20.04 (glibc 2.31) is provided in `scripts/test/ui/toolchain-armv5/`:

```sh
# Build toolchain and firmware on docker-dev remote or local context
./scripts/test/ui/toolchain-armv5/build-in-docker.sh
```

The containerized pipeline:
- Validates the ARMv5 external toolchain (`arm-buildroot-linux-uclibcgnueabi-gcc 7.4.0`).
- Configures `BISON_PKGDATADIR` and `gawk -c` compatibility wrappers.
- Compiles the Linux 4.14 kernel and all staging packages in an isolated volume.
- Produces signed and verified firmware images (`Alt-F-*.bin` and `.sha1`).

### Flash Partition Limits
Firmware generation rigorously verifies binary sizes against U-Boot bootloader limits:
- **Kernel (`uImage`):** Maximum 3,145,728 bytes (3.0 MiB)
- **Rootfs Initramfs (`urootfs`):** Maximum 3,145,728 bytes (3.0 MiB)
- **Extra Flash Partition (`ubimage.lzo`):** Up to 104,857,600 bytes (~100 MiB) on 128MB NAND flash models

---

## Testing & Quality Assurance

### Automated UI Verification Suite
Alt-F includes a multi-tier automated test suite executed in isolated Docker containers:

```sh
# Run all test suites
./scripts/test/ui/run_ui_checks.sh --suite all

# Run specific suites
./scripts/test/ui/run_ui_checks.sh --suite static     # Shell syntax with BusyBox ash, form contracts, file inventories
./scripts/test/ui/run_ui_checks.sh --suite render     # Shared UI helper HTML/layout rendering tests
./scripts/test/ui/run_ui_checks.sh --suite browser    # Playwright browser automation across 112 administrative routes
./scripts/test/ui/run_ui_checks.sh --suite budget     # Strict 100 KiB CSS/JS asset budget verification
```

### ARMv5 Validation & Emulation
- **Target Syntax & Helper Verification:** `scripts/test/ui/toolchain-armv5/run-arm-ui-validation.sh` builds BusyBox for ARMv5 soft-float and executes all 153 CGI scripts under QEMU user-static emulation to guarantee zero architecture-specific syntax regressions.
- **Full System Emulation:** `./qemu-Alt-F.sh` boots an Alt-F image inside QEMU on an emulated ARM Versatile PB platform, exposing the web UI on `localhost:5555` and SSH on `localhost:5556`.

---

## Repository Structure

```
├── .config              # Active Buildroot configuration (generated by exports)
├── exports              # Environment setup script (sourced via . exports <board>)
├── mktc.sh              # External toolchain builder (Buildroot 2019.02.8 + uClibc-ng)
├── mkinitramfs.sh       # Root filesystem assembly script (SquashFS / UBIFS)
├── mkfw.sh              # Vendor firmware header injection and packaging script
├── configfs             # Post-build staging script for target filesystem overlay
├── rootfsfiles-base.lst # Master file inventory for base firmware packages
├── customroot/          # Target root filesystem overlay
│   ├── etc/init.d/      # SysV-style init scripts (S??<service>)
│   └── usr/www/         # Web administration interface (BusyBox httpd)
│       ├── cgi-bin/     # Shell CGI scripts (page.cgi / page_proc.cgi)
│       └── scripts/     # Modular themes, CSS, and lightweight JavaScript
├── ipkgfiles/           # Control files, dependencies, and file lists for ipkg packages
├── local/               # Board-specific configurations (dns320, dns325, dns327, etc.)
├── package/             # Buildroot package makefiles and patch sets
├── docs/                # Architecture documentation, Wiki mirrors, and guides
└── scripts/
    └── test/ui/         # Automated UI test runners, fixtures, and Docker environments
```

---

## Official Resources & Documentation

- **Documentation Portal (GitHub Pages):** [https://samuelcaldas.github.io/alt-f/](https://samuelcaldas.github.io/alt-f/)
- **Original Google Site Mirror:** [https://sites.google.com/site/altfirmware/alt-f](https://sites.google.com/site/altfirmware/alt-f)
- **SourceForge Project Page:** [https://sourceforge.net/projects/alt-f/](https://sourceforge.net/projects/alt-f/)
- **SourceForge Wiki:** [https://sourceforge.net/p/alt-f/wiki/Alt-F%20Wiki/](https://sourceforge.net/p/alt-f/wiki/Alt-F%20Wiki/)
- **Subversion Source Repository:** [https://sourceforge.net/p/alt-f/code/HEAD/tree/](https://sourceforge.net/p/alt-f/code/HEAD/tree/)
- **Community Forum & Discussion:** [Alt-F Google Group](https://groups.google.com/group/alt-f)
- **Detailed User Guide:** [README.USE](README.USE)
- **Installation Guide:** [README.INSTALL](README.INSTALL)
- **UI Architecture Documentation:** [docs/ui-development.md](docs/ui-development.md)

---

## License & Acknowledgments

- **License:** Alt-F is free software licensed under the [GNU General Public License v2 (GPL-2.0)](COPYING).
- **Original Author & Maintainer:** João Cardoso (`jcard`).
- **Community:** Special thanks to all Alt-F contributors, testers, and forum members across the globe who have kept these reliable NAS devices secure, updated, and useful.
