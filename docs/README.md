# Alt-F Developer & Architecture Documentation

This document serves as the developer handbook and architectural reference for the Alt-F project, consolidating technical specifications, build system mechanics, runtime architecture, and testing guidelines.

---

## 1. Architecture Overview

Alt-F is an embedded Linux distribution designed for D-Link ARM-based Network Attached Storage devices. It combines:
1. **Linux Kernel 4.14 LTS:** Customized for Marvell Orion (88F5181/88F5182), Kirkwood (88F6281/88F6702), and Armada 370 (88F6707) SoCs.
2. **uClibc-ng C Library:** Highly optimized, minimal C library replacing glibc to run within embedded RAM limits (64MB–512MB).
3. **BusyBox:** Multi-call binary providing POSIX shell (`ash`), lightweight system utilities, core networking tools, and the `httpd` web server.
4. **Flash Execution Model:** The root filesystem executes directly from compressed SquashFS and UBI/UBIFS images stored in NAND/NOR flash memory, preserving maximum RAM for file caching, daemons, and user processes.

---

## 2. Directory Structure

| Path | Purpose |
| :--- | :--- |
| `exports` | Shell script sourced (`. exports <board>`) to set environment variables (`BLDDIR`, `ROOTFS`, `KERNEL`, `BINARIES`, `PATH`) and configure `.config`. |
| `mktc.sh` | Builds the external Buildroot 2019.02.8 toolchain with GCC 7.4.0 and uClibc-ng. |
| `mkinitramfs.sh` | Assembles the base root filesystem (`rootfs.arm.sqall.xz`) and extra package image (`rootfs.arm.sqimage.xz` / `rootfs.arm.ubimage.lzo`). |
| `mkfw.sh` | Prepends machine-specific prologues/device trees and injects vendor D-Link firmware headers using `dns323-fw`. |
| `configfs` | Script called during `BR2_ROOTFS_POST_BUILD_SCRIPT` to clean unwanted files and apply the `customroot/` overlay to the target root. |
| `rootfsfiles-base.lst`| Authoritative file list of base firmware components. |
| `customroot/` | Staging overlay copied directly into the target root filesystem. |
| `customroot/etc/init.d/` | SysV-style init scripts with metadata headers (`DESC=`, `TYPE=sys|net|user|required`, `REQUIRE=`). |
| `customroot/usr/www/cgi-bin/` | Administrative web application written in POSIX shell CGI. |
| `customroot/usr/www/scripts/` | Web interface assets (CSS themes, JavaScript modules). |
| `ipkgfiles/` | Packaging metadata (`.control`, `.lst`, `.conffiles`, `.preinst`, `.postinst`, etc.) for disk/flash-installable ipkg packages. |
| `local/<board>/` | Board profiles (`dns323`, `dns325`, `dns327`, `qemu`, `pkgs`) containing board `.config`, Linux kernel `.config`, and uClibc/BusyBox configurations. |
| `package/` | Buildroot package makefiles (`<pkg>.mk`) and patches. Uses `$(eval $(call AUTOTARGETS,...))`. |
| `scripts/test/ui/` | Automated test suite and Docker validation environments for web UI and ARM toolchains. |

---

## 3. Web Administration Interface

### 3.1 Design Principles
- **BusyBox POSIX Shell CGI:** All administrative logic runs as POSIX `/bin/sh` scripts under BusyBox `httpd`. No bashisms or external runtime interpreters (e.g., Python, Node.js) are used on the NAS.
- **Pair Contract:** Every administrative section uses a paired architecture:
  - `<feature>.cgi`: Renders the HTML configuration form.
  - `<feature>_proc.cgi`: Processes the form submission (`POST` or `GET`), applies system changes, and redirects or displays feedback.
- **Shared Presentation Helpers:**
  - `common.sh`: Core shared routines (`check_cookie`, `read_args`, `write_header`, `write_footer`, `html_header`, `service_restart`, input validators).
  - `ui_shell.sh`: Semantic HTML5 document shell, viewport configuration, skip-links, and layout wrappers.
  - `ui_navigation.sh`: Dynamic navigation generation from `.men` files.
  - `ui_menu.awk`: Fast awk parser generating accessible HTML menus from menu definition files.
- **Strict Budget:** Combined CSS and JavaScript assets are capped under 100 KiB per page to guarantee responsive rendering on slow embedded CPUs.
- **Session Authentication:** Handled via MD5 salt challenge in `login.cgi` and `login_proc.cgi`, setting the `ALTFID` cookie with a 30-minute inactivity timeout. `status.cgi` remains publicly accessible without cookies for external monitoring.

---

## 4. Build System & Toolchain

### 4.1 Build Flow
```sh
# 1. Select board and setup environment
. exports dns325 /path/to/build

# 2. Build cross-toolchain (first time only)
./mktc.sh

# 3. Compile all enabled packages and kernel
make >& build.log

# 4. Generate rootfs images
./mkinitramfs.sh

# 5. Pack final firmware binaries
./mkfw.sh
```

### 4.2 Modern Containerized Build (Ubuntu 20.04)
Modern host systems with glibc $\ge$ 2.33 remove declarations required by legacy build tools (specifically `fakeroot` 1.9.5). The reproducible build pipeline in `scripts/test/ui/toolchain-armv5/`:
- Uses `ubuntu:20.04` (glibc 2.31) in Docker.
- Exports `BISON_PKGDATADIR` for Bison 3.0.4 compatibility.
- Wraps `gawk` with `-c` compatibility mode to avoid conflicts with the `namespace` keyword in `libgpg-error`.
- Automatically maps legacy `arm-linux-*` tool aliases.

---

## 5. Testing & Verification

Automated testing is required for all changes:

```sh
# Run full UI test suite (static, render, browser, budget)
./scripts/test/ui/run_ui_checks.sh --suite all

# Run ARMv5 BusyBox & CGI syntax validation via QEMU user-static
./scripts/test/ui/toolchain-armv5/run-arm-ui-validation.sh
```

---

## 6. Official References

- **SourceForge Project:** [https://sourceforge.net/projects/alt-f/](https://sourceforge.net/projects/alt-f/)
- **SourceForge Wiki:** [https://sourceforge.net/p/alt-f/wiki/Alt-F%20Wiki/](https://sourceforge.net/p/alt-f/wiki/Alt-F%20Wiki/)
- **SVN Repository:** [https://sourceforge.net/p/alt-f/code/HEAD/tree/](https://sourceforge.net/p/alt-f/code/HEAD/tree/)
- **Google Groups Forum:** [https://groups.google.com/group/alt-f](https://groups.google.com/group/alt-f)
