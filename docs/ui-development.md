# Developing the Alt-F web interface

## Runtime

The NAS still uses BusyBox httpd and shell CGI. There is no frontend build or new
resident service. `common.sh` delegates presentation to `ui_shell.sh` and
`ui_navigation.sh`; `ui_menu.awk` renders the existing `.men` files efficiently.
Links use ordinary same-window navigation, and forms keep their original fields,
POST actions, and multipart behavior.

`write_header` opens the administrative shell; `write_footer` closes it.
`html_header` is a minimal document for dialogs, errors, progress, and embedded
services. Do not add the administrative shell to downloads, redirects, or status
refresh responses. `status.cgi` remains public, matching its existing behavior.
The login challenge and session mechanism are unchanged by this presentation work.

## Themes and presentation

The `default.thm` symlink still selects `dull.thm`. That built-in theme now supplies
responsive styling. `demo.thm` retains its existing overrides. Select `classic`
on the System Utilities page for the previous appearance; it also uses frame-free
navigation. The shared layout/behavior assets are loaded separately, exactly once.
Existing third-party themes that access the removed `nav`/`content` frames need
adaptation; uploaded theme compatibility cannot be guaranteed.

Wide data tables keep all columns inside scrollable regions. Narrow forms use a
stacked layout. The new JavaScript enhances menus, labels, tables, tooltips, and
bookmarks; it does not intercept normal form submissions or introduce polling.
The existing status refresh intervals remain unchanged.

## Development checks

Docker must have the `docker-dev` context. Run from the repository root:

```sh
scripts/test/ui/run_ui_checks.sh --suite all
scripts/test/ui/run_ui_checks.sh --suite static
scripts/test/ui/run_ui_checks.sh --suite render
scripts/test/ui/run_ui_checks.sh --suite browser
scripts/test/ui/run_ui_checks.sh --suite budget
```

The runner transfers the build context to the remote daemon; it does not assume
that local repository paths exist on that server. Browser dependencies exist only
in the test image. Build steps use the development host's network for dependency
resolution (`ALT_F_BUILD_NETWORK=default` can override this); this avoids changing
Docker or DNS settings. Test containers have no network access except loopback, no added
capabilities, no host/NAS settings mounts, and no storage devices. Screenshots and
route-coverage reports are copied back to `.playwright-mcp/`, which is ignored by Git.

### What these checks prove

- BusyBox ash syntax, preserved submitted-field contracts, removal of navigation
  frame references, local assets, and inclusion in `rootfsfiles-base.lst`.
- Actual shared helper output: HTML, menus, titles, redirects, synthetic session
  files, explicit service iframes, and download headers.
- Browser layout at 360/768/1280 pixels, keyboard-accessible navigation, automated
  accessibility on a representative fixture, native POST, multipart, and downloads.
- Production CSS/JS plus a conservative count of source inline scripts, styles,
  and literal `LOCAL_STYLE` assignments remain
  within a 100 KiB per-page budget. This is not a measurement of dynamically
  generated data or compressed firmware size.

**Browser page bodies are explicitly synthetic.** The harness renders actual shared
presentation for each identified route but does not execute arbitrary original
administrative CGI, mutate disks, or start real NAS services. The coverage report
labels those fixtures and unavailable integrations. Real page-specific behavior,
first-boot setup, theme persistence, and third-party interfaces still require
validation in an isolated target environment and on the A3 before deployment.

A pre-existing missing `fi` makes `ddns_proc.cgi` fail `ash -n` in the baseline
commit too. The suite reports this known defect and excludes only that unchanged,
SHA-256-checked file from the syntax check. The modernization does not fix it.

## ARMv5 toolchain and shell verification

Build/reuse the isolated ARMv5 toolchain and inspect its ELF/ABI offline:

```sh
scripts/test/ui/toolchain-armv5/build-in-docker.sh
scripts/test/ui/toolchain-armv5/run-arm-ui-validation.sh
```

The toolchain uses the repository's Buildroot 2019.02.8 inputs, GCC 7.4.0 and
uClibc-ng 1.0.44. Its output/cache stays in the named Docker volume
`alt-f-armv5-toolchain-buildroot-2019.02.8`. Verification checks ARM926EJ-S/v5TEJ,
EABI5, no VFP calling convention, and dynamic linkage to the uClibc loader.
The ARM UI runner builds the configured/patched BusyBox 1.20.2 and uses QEMU user
emulation for syntax and shared-helper checks, never real service handlers.

Host-compatibility fixes and HTTPS mirrors apply only inside the disposable
Buildroot workspace. No GCC build is repeated for a valid cached output; the
original `mktc.sh` and configs stay unchanged. A successful cached build is not
proof of a complete cold-cache or firmware build. Host root access, if needed,
must use `ssh root@localhost`, not sudo; routine builds need only Docker access.

## Firmware and target verification

Add new runtime files to `rootfsfiles-base.lst`; keep development tests outside
`customroot/`. CGI owned by installable packages also needs verification when those
packages are rebuilt; these changes do not produce or publish updated `.ipk` files.
The existing `configfs` overlay hook installs the runtime files.

Build for **dns325/ARMv5**, not dns327/ARMv7, using the repository's sourced `exports`
and ARM toolchain. Respect the existing model-specific limits in `mkfw.sh`: kernel
and initramfs each 3 MiB, extra image 100 MiB. Do not increase them to accommodate UI
assets. A firmware build requires the toolchain and build tree, which the UI runner
does not download or create.

`qemu-Alt-F.sh` downloads an existing release. To test these changes in QEMU, build
an image from this checkout or explicitly install this overlay into the guest.
Neither the x86 test container nor QEMU certifies real A3 resource use. On the
hardware, check login/logout/expiry, first boot, all visible menus, read-only status,
back/forward, a safe settings change, save/restore, and memory/CPU/transfer behavior.
Never flash firmware, change bootloaders, or perform disk operations as part of the
UI checks. Those actions need separate authorization and recovery preparation.

## Reverse proxy preview

If a preview is exposed through Nginx Proxy Manager, configure it manually: use
the development hostname, preserve `/cgi-bin/` and `/scripts/`, forward the host and
protocol headers, and disable caching for CGI/authentication responses. Configure
upload limits for the intended test payloads. Do not expose the synthetic harness
or NAS administration publicly; the automated tests need no proxy configuration.
