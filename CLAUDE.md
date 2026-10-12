# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Alt-F: alternative firmware for D-Link ARM NAS boxes (DNS-320/320L/321/323/325/327L and rebrands). It is a heavily customized **old Buildroot tree** (Kconfig + `package/*/*.mk`) that cross-compiles a uClibc/BusyBox Linux system, plus shell scripts that assemble the root filesystem and flashable firmware images. There is no test suite or linter; "testing" means building and booting (on hardware or in QEMU).

`AGENTS.md` and `GEMINI.md` are symlinks to this file. `README.md` is a placeholder. `README.BUILD` is outdated (svn, RC4) — use the flow below. `README.INSTALL` / `README.USE` are end-user docs.

## Build flow

All scripts must be run from the repo root. `exports` must be **sourced**, not executed.

```sh
. exports dns325 [build_dir]   # copy local/<board>/<board>.config -> .config, set BLDDIR/ROOTFS/KERNEL/BINARIES/PATH, run oldconfig
./mktc.sh                       # first time only: downloads Buildroot 2019.02.8 into $BLDDIR/br-*, builds the external uClibc-ng toolchain
make >& build-dns325.log        # build everything enabled in .config into $BLDDIR
./mkinitramfs.sh [type] [comp]  # assemble rootfs image(s); re-runs itself via sudo -E (loop mounts)
./mkfw.sh [type] [comp]         # produce Alt-F-*.bin firmware in $BINARIES
```

- Boards (`local/<board>/`): `dns323` (DNS-321/323), `dns325` (DNS-320/320L/325), `dns327` (DNS-327L, armv7), `qemu`, `pkgs` (config used to build disk-installable packages). The full model/revision → firmware-file mapping is the `name=(...)` array in `mkfw.sh`. Default build dir is `./build` (gitignored, as are `dl/`, `binaries/`, `.config`).
- Switching boards with an existing `.config`: `exports` diffs board/uClibc/BusyBox/kernel configs and refuses if they changed; save with `make saveconfig` (writes back to `local/<board>/`) or force with `. exports -f <board>`.
- Image types: `cpio`, `squsr`, `sqall` (default, xz), `sqsplit`, `ubisplit` (lzo). `sqsplit`/`ubisplit` are only for dns325/dns327 (and are their default).
- Config: `make menuconfig` (top-level `Config.in` → `package/Config.in`, `target/`, `toolchain/`, `project/`). `make help` lists targets.
- Per-package targets (from `package/Makefile.autotools.in`): `make <pkg>`, `<pkg>-source`, `-extract`, `-patch`, `-configure`, `-build`, `-install-target`, `-uninstall`, `-clean`, `-dirclean`. Rebuilding a single package: `make <pkg>-dirclean && make <pkg>`.
- Emulation: `qemu-Alt-F.sh` boots a released Alt-F image on an emulated Versatile PB board (web UI on `localhost:5555`, ssh on `5556`).

## Architecture

**Packages (`package/<name>/`)** — Old-style Buildroot makefiles using `$(eval $(call AUTOTARGETS,package,<name>))` (and `AUTOTARGETS_HOST`), not modern `$(eval $(autotools-package))`. Variables are `<NAME>_VERSION/_SITE/_SOURCE/_DEPENDENCIES/_CONF_OPT/_INSTALL_TARGET_OPT`, etc. Patches live alongside as `<name>-<version>-*.patch`. Several packages have multiple variants (e.g. `samba`, `samba36`, `samba4`, `samba-small`).

**Root filesystem overlay (`customroot/`)** — Alt-F's own runtime: copied into the target root. `configfs` is the `BR2_ROOTFS_POST_BUILD_SCRIPT`; it strips unwanted files from packages and installs the overlay before the rootfs is built.
- `customroot/etc/init.d/S<NN><name>`: SysV-style init scripts. Each declares `DESC=`, `TYPE=` (`sys`/`net`/`user`/`required`) and optional `REQUIRE=`; `TYPE` decides which web-UI services page lists it. `/sbin/rc<name>` is a symlink to `/usr/sbin/rcscript`, which dispatches to `S??<name>`.
- `customroot/usr/www/cgi-bin/`: the web admin UI, written entirely in **POSIX sh CGI** (BusyBox httpd). Pages come in pairs: `<name>.cgi` renders the form, `<name>_proc.cgi` handles the submit. Both start with `. common.sh; check_cookie` and use helpers from `common.sh` (`read_args`, `write_header`, `msg`, `service_restart`, validators like `checkip`/`checkport`). Form values must be decoded with `httpd -d`. Menus are the `*.men` files (`Label|page.cgi`). Help pages are `customroot/usr/www/*_hlp.html`.
- This code runs on the box under BusyBox ash — no bashisms, and only tools present in the firmware.

**Disk-installable packages (`ipkgfiles/`)** — ipkg metadata per package: `<pkg>.control` (Version, Depends, …), `<pkg>.lst` (owned file list), and optional `.conffiles`/`.preinst`/`.postinst`/`.prerm`/`.postrm`. `mkpkg.sh` creates the `.ipk` by diffing the rootfs against a recorded file list (`./mkpkg.sh -set`, build, `./mkpkg.sh <pkg>`; see the script header for the full workflow and `-check`, `-diff`, `-all`, `-index`). A user-facing package that appears in the web UI also needs an `S8?<pkg>` init script with `TYPE=user`, `/etc/<pkg>.conf`, and a `<pkg>.cgi` + `<pkg>_proc.cgi` pair. `rootfsfiles-base.lst` is the base firmware file list; `rdeps <pkg>` prints a package's recursive deps; `pkgs-check.sh`/`pkgs-update.sh` compare against released packages.

**Firmware assembly** — `mkinitramfs.sh` builds the base rootfs from the packages chosen in `.config` plus their ipkg deps, and for `sq*` types an extra squashfs (`sqimage`) holding a fixed set of packages (`sq_pkgs`) and kernel modules. `mkfw.sh` wraps kernel + rootfs into vendor-flashable `.bin` files per board revision. Kernel configs are in `local/<board>/linux-<ver>.config`; BusyBox/uClibc configs are referenced from the board `.config`.

## Conventions

- Shell scripts use tabs (`.editorconfig` says 4 spaces, but existing scripts and makefiles use tabs — match the file you edit).
- Changes to firmware behaviour usually touch several layers together: `package/<pkg>` (build), `customroot/` (init script / config / CGI), and `ipkgfiles/<pkg>.*` (packaging, bump `Version:`).

## Containerized Build Environment

- Build host requirements: Ubuntu 20.04 container (glibc <= 2.31 for `fakeroot` 1.9.5 `_STAT_VER` compatibility; newer glibc drops `__xstat64` declarations).
- Toolchain scripts: `scripts/test/ui/toolchain-armv5/` contains automated builders for ARMv5 toolchain and firmware assembly on `docker-dev`.
- Host tool quirks: `gawk -c` is required (gawk 5.0+ reserves `namespace`); `BISON_PKGDATADIR` must point to host bison 3.0.4 skeletons; util-linux `rename.ul` satisfies `mkinitramfs.sh`'s `rename` syntax.
