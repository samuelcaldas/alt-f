#!/usr/bin/env bash
set -Eeuo pipefail

readonly compiler=/out/build/br-2019.02.8/output/host/bin/arm-buildroot-linux-uclibcgnueabi-gcc
readonly sysroot=/out/build/br-2019.02.8/output/host/arm-buildroot-linux-uclibcgnueabi/sysroot
readonly cgi_dir=/src/cgi-bin
readonly busybox_config=/src/busybox-1.20.2.config
readonly busybox_patches=/src/busybox-patches
readonly www_scripts=/src/www/scripts
readonly work_dir=/tmp/arm-ui-validation
readonly source_archive="$work_dir/download/busybox-1.20.2.tar.bz2"
readonly input_archive=/input/busybox-1.20.2.tar.bz2
readonly input_checksum=/input/busybox-1.20.2.tar.bz2.sha256
readonly source_dir="$work_dir/source/busybox-1.20.2"
readonly build_dir="$work_dir/build"

fail() {
    printf 'ARM UI validation failed: %s\n' "$1" >&2
    exit 1
}

[[ -x "$compiler" ]] || fail "cross compiler unavailable: $compiler"
[[ -d "$sysroot" ]] || fail "toolchain sysroot unavailable: $sysroot"
[[ -f "$busybox_config" ]] || fail 'BusyBox config unavailable'
[[ -d "$www_scripts" ]] || fail 'copied www scripts unavailable'
command -v qemu-arm-static >/dev/null || fail 'qemu-arm-static unavailable'

mkdir -p "$work_dir/download" "$work_dir/source" "$build_dir"
[[ -f "$input_archive" && -f "$input_checksum" ]] || fail 'downloaded BusyBox source or checksum is missing'
cp "$input_archive" "$source_archive"
cp "$input_checksum" "$work_dir/download/busybox-1.20.2.tar.bz2.sha256"
(cd "$work_dir/download" && sha256sum --check busybox-1.20.2.tar.bz2.sha256)
printf 'BusyBox archive SHA-256: '
sha256sum "$source_archive"
tar -xjf "$source_archive" -C "$work_dir/source"

for patch_file in "$busybox_patches"/busybox-1.20.2-*.patch; do
    [[ -f "$patch_file" ]] || continue
    printf 'Applying %s\n' "$(basename "$patch_file")"
    patch --directory="$source_dir" --strip=1 --forward < "$patch_file"
done

cp "$busybox_config" "$source_dir/.config"
sed -i 's|^CONFIG_PREFIX=.*|CONFIG_PREFIX="/tmp/arm-ui-validation/install"|' "$source_dir/.config"
readonly cross_prefix="${compiler%gcc}"

printf 'Configuring BusyBox 1.20.2 for ARMv5 soft-float.\n'
oldconfig_status=0
yes '' | make --directory="$source_dir" \
    ARCH=arm CROSS_COMPILE="$cross_prefix" oldconfig > "$build_dir/oldconfig.log" || oldconfig_status=$?
if [[ "$oldconfig_status" != 0 && "$oldconfig_status" != 141 ]]; then
    cat "$build_dir/oldconfig.log" >&2
    fail "BusyBox oldconfig failed with status $oldconfig_status"
fi
printf 'Building BusyBox 1.20.2.\n'
make --directory="$source_dir" -j2 \
    ARCH=arm CROSS_COMPILE="$cross_prefix" busybox

readonly busybox_binary="$source_dir/busybox"
[[ -x "$busybox_binary" ]] || fail 'BusyBox build did not produce an executable'
file "$busybox_binary"
readelf -h "$busybox_binary" | grep -E 'Class:|Machine:|Flags:'
readelf -A "$busybox_binary" | tee "$build_dir/busybox-arm-attributes.txt"
if grep -Eq 'Tag_CPU_arch: v7|Tag_CPU_arch: v8|Tag_ABI_VFP_args: VFP registers' "$build_dir/busybox-arm-attributes.txt"; then
    fail 'BusyBox ELF is not ARMv5 soft-float compatible'
fi
if ! grep -Eiq 'Tag_CPU_arch: v5|Tag_CPU_name:.*arm926' "$build_dir/busybox-arm-attributes.txt"; then
    fail 'BusyBox ELF does not advertise ARMv5-class attributes'
fi
readelf -l "$busybox_binary" | grep 'Requesting program interpreter'
readelf -d "$busybox_binary" | grep NEEDED

readonly shim_dir="$build_dir/arm-applets"
mkdir -p "$shim_dir"
for applet in awk sed cat basename grep hexdump; do
    cat > "$shim_dir/$applet" <<SHIM
#!/bin/sh
printf '%s\n' "$applet" >> "\$ARM_UI_APPLET_LOG"
exec qemu-arm-static -L "$sysroot" "$busybox_binary" "$applet" "\$@"
SHIM
    chmod +x "$shim_dir/$applet"
done
export ARM_UI_APPLET_LOG="$build_dir/applet-invocations.log"
printf 'alpha\n' | "$shim_dir/cat" >/dev/null
printf 'alpha\n' | "$shim_dir/grep" -q alpha
printf 'alpha\n' | "$shim_dir/sed" 's/alpha/beta/' | "$shim_dir/grep" -q beta
[[ "$("$shim_dir/basename" /tmp/fixture)" == fixture ]]
printf 'key|value\n' | "$shim_dir/awk" -F '|' '{print $2}' | "$shim_dir/grep" -q value
printf 'x' | "$shim_dir/hexdump" -C >/dev/null
printf 'ARM BusyBox applet wrapper smoke checks passed: 6.\n'
mkdir -p /usr/www/scripts
cp -a "$www_scripts/." /usr/www/scripts/
[[ -f /usr/www/scripts/default.thm ]] || fail 'copied default theme is missing'

printf '\nChecking CGI and shell syntax with the compiled ARM BusyBox ash.\n'
syntax_count=0
while IFS= read -r -d '' script_file; do
    case "$script_file" in
        */ddns_proc.cgi)
            printf 'SKIP %s (baseline defect excluded by task scope)\n' "${script_file#"$cgi_dir"/}"
            continue
            ;;
    esac
    qemu-arm-static -L "$sysroot" "$busybox_binary" ash -n "$script_file"
    syntax_count=$((syntax_count + 1))
done < <(find "$cgi_dir" -maxdepth 1 -type f \( -name '*.cgi' -o -name '*.sh' \) -print0 | sort -z)
printf 'Syntax checks passed: %s; skipped baseline ddns_proc.cgi.\n' "$syntax_count"

printf '\nRendering actual shared UI helper fixture using ARM BusyBox ash.\n'
cat > "$build_dir/render-fixture.sh" <<'EOF'
#!/bin/ash
set -eu
PATH="$ARM_UI_BUSYBOX_SHIMS:$PATH"
export PATH
cat > /etc/misc.conf <<'CONF'
HTTPD_LOG=no
SIDE_MENU=yes
TOP_MENU=yes
CONF
cd /src/cgi-bin
. ./common.sh
loadsave_settings() { return 0; }
url_encode() { printf '%s' "$1"; }
mktt() { :; }
ttip() { :; }
SIDE_MENU=yes
TOP_MENU=yes
LOCAL_STYLE='.fixture { color: black; }'
HTTP_HOST=nas.example
SCRIPT_NAME=/cgi-bin/status.cgi
REQUEST_URI=/cgi-bin/status.cgi
UI_PAGE_FULL=no
ui_document_head 'Fixture <title>'
ui_document_body ''
ui_page_title 'Fixture page'
ui_settings_notice
write_footer
EOF
: > "$build_dir/applet-invocations.log"
ARM_UI_BUSYBOX_SHIMS="$shim_dir" qemu-arm-static -L "$sysroot" "$busybox_binary" ash "$build_dir/render-fixture.sh" > "$build_dir/rendered.html"
for applet in awk sed cat basename grep; do
    grep -qx "$applet" "$build_dir/applet-invocations.log" || fail "render fixture did not dispatch to ARM BusyBox $applet"
done
grep -q 'Fixture &lt;title&gt;' "$build_dir/rendered.html"
grep -q 'href="/scripts/dull/dull.css"' "$build_dir/rendered.html"
grep -q 'class="ui-page ui-sidebar ui-both"' "$build_dir/rendered.html"
grep -q 'id="top-navigation"' "$build_dir/rendered.html"
grep -q '<main id="main-content"' "$build_dir/rendered.html"
grep -q '</body></html>' "$build_dir/rendered.html"
printf 'Shared helper render fixture passed (%s bytes) using ARM awk/sed/cat/basename/grep.\n' "$(wc -c < "$build_dir/rendered.html")"
