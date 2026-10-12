#!/usr/bin/env bash
set -Eeuo pipefail

readonly sdk_root=/out/build/br-2019.02.8
readonly sdk_host="$sdk_root/output/host"
readonly sdk_compiler="$sdk_host/bin/arm-buildroot-linux-uclibcgnueabi-gcc"
readonly sdk_sysroot="$sdk_host/arm-buildroot-linux-uclibcgnueabi/sysroot"
readonly external_path=/out/build/br-2019.02.8/output/host
readonly external_prefix=arm-buildroot-linux-uclibcgnueabi
readonly firmware_root=/firmware
readonly source_root="$firmware_root/source"
readonly build_root="$firmware_root/build"
readonly source_archive=/firmware-input/source.tar
readonly status_file="$firmware_root/firmware-make.exitcode"
export FORCE_UNSAFE_CONFIGURE=1
export BISON_PKGDATADIR="$build_root/build_arm/host_dir/usr/share/bison"

stage='SDK validation'
stop() {
    printf 'FIRMWARE_STOP_STAGE=%s\nFIRMWARE_STOP_REASON=%s\n' "$stage" "$1" >&2
    exit 2
}

[[ -f "$sdk_root/.config" ]] || stop 'Buildroot SDK source/config marker is absent'
[[ -f /out/build/.toolchain-build.exitcode ]] || stop 'validated SDK status marker is absent'
[[ "$(cat /out/build/.toolchain-build.exitcode)" == 0 ]] || stop 'validated SDK build status is not zero'
[[ -x "$sdk_compiler" ]] || stop 'ARM EABI GCC is absent from the read-only SDK'
[[ -f "$sdk_sysroot/lib/ld-uClibc.so.0" ]] || stop 'uClibc loader is absent from the SDK sysroot'
if touch /out/.firmware-write-check 2>/dev/null; then
    rm -f /out/.firmware-write-check
    stop 'SDK volume is unexpectedly writable'
fi
[[ -f "$source_archive" ]] || stop 'source-only archive is missing from the image'

stage='source staging'
if [[ -d "$source_root/dl" ]]; then
    mv "$source_root/dl" /tmp/saved-dl
fi
rm -rf "$source_root"
mkdir -p "$source_root" "$build_root"
tar -xf "$source_archive" -C "$source_root"
if [[ -d /tmp/saved-dl ]]; then
    mkdir -p "$source_root/dl"
    mv /tmp/saved-dl/* "$source_root/dl/" 2>/dev/null || true
    rm -rf /tmp/saved-dl
fi
[[ -f "$source_root/exports" && -f "$source_root/Makefile" ]] || stop 'firmware source archive is incomplete'

stage='external toolchain configuration'
board_config="$source_root/local/dns325/dns325.config"
[[ -f "$board_config" ]] || stop 'DNS-325 configuration is missing'
sed -i "s|^BR2_TOOLCHAIN_EXTERNAL_PATH=.*$|BR2_TOOLCHAIN_EXTERNAL_PATH=\"$external_path\"|" "$board_config"
sed -i "s|^BR2_TOOLCHAIN_EXTERNAL_PREFIX=.*$|BR2_TOOLCHAIN_EXTERNAL_PREFIX=\"$external_prefix\"|" "$board_config"
alias_bin="$source_root/build/br-2019.02.8/output/host/bin"
mkdir -p "$alias_bin"
for tool in "$sdk_host/bin"/*; do
    ln -sfn "$tool" "$alias_bin/$(basename "$tool")"
done

stage='exports and config preflight'
cd "$source_root"
OPATH="$PATH"
source ./exports dns325 "$build_root"
[[ -x "$alias_bin/arm-linux-gcc" ]] || stop 'exports did not resolve its legacy arm-linux-gcc alias'
[[ "$("$sdk_compiler" -dumpmachine)" == "$external_prefix" ]] || stop 'SDK compiler target differs from configured prefix'
[[ "$("$sdk_compiler" -print-sysroot)" == "$sdk_sysroot" ]] || stop 'SDK compiler sysroot path differs from the mounted SDK'
grep -Fx "BR2_TOOLCHAIN_EXTERNAL_PATH=\"$external_path\"" .config >/dev/null || stop 'resolved config lost the mounted SDK path'
grep -Fx "BR2_TOOLCHAIN_EXTERNAL_PREFIX=\"$external_prefix\"" .config >/dev/null || stop 'resolved config lost the SDK compiler prefix'
printf 'FIRMWARE_PREFLIGHT=passed\n'
printf 'SDK compiler: %s\nTarget: %s\nSysroot: %s\n' "$sdk_compiler" "$external_prefix" "$sdk_sysroot"
printf 'Legacy exports alias: %s\n' "$alias_bin/arm-linux-gcc"
printf 'Firmware output: %s\n' "$build_root"

stage='make world'
cd "$source_root"
status=0
make V=1 -j1 || status=$?
printf '%s\n' "$status" > "$status_file"
printf 'FIRMWARE_MAKE_EXIT=%s\n' "$status"

if [[ "$status" -eq 0 ]]; then
    stage='assemble initramfs'
    ./mkinitramfs.sh || status=$?
    printf 'FIRMWARE_INITRAMFS_EXIT=%s\n' "$status"
fi

if [[ "$status" -eq 0 ]]; then
    stage='assemble firmware'
    ./mkfw.sh || status=$?
    printf 'FIRMWARE_MKFW_EXIT=%s\n' "$status"
fi

exit "$status"
