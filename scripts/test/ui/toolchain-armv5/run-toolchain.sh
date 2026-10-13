#!/usr/bin/env bash
set -Eeuo pipefail

readonly build_root=/out/build
readonly buildroot_version=2019.02.8
readonly buildroot_root="$build_root/br-$buildroot_version"
readonly compiler_prefix="$buildroot_root/output/host/bin/arm-buildroot-linux-uclibcgnueabi-"
readonly compiler="${compiler_prefix}gcc"
readonly toolchain_status="$build_root/.toolchain-build.exitcode"

if [[ ! -f .config || ! -f local/buildroot-2019.02.8.config || ! -f local/uclibc-1.0.31.config ]]; then
    printf 'Required Buildroot inputs are missing from the isolated workspace.\n' >&2
    exit 2
fi

export BLDDIR="$build_root"
mkdir -p "$build_root/dl"

mode="${1:-verify}"
if [[ "$mode" == build ]]; then
    if [[ ! -x "$compiler" || ! -f "$toolchain_status" || "$(cat "$toolchain_status")" != 0 ]]; then
        build_workspace="$(mktemp -d /tmp/armv5-mktc.XXXXXX)"
        mkdir -p "$build_workspace/local" /tmp/toolchain-compat
        cp ./mktc.sh "$build_workspace/mktc.sh"
        cp ./local/buildroot-2019.02.8.config "$build_workspace/local/"
        cp ./local/uclibc-1.0.31.config "$build_workspace/local/"
        cp .config "$build_workspace/.config"
        ln -s "$build_root/dl" "$build_workspace/dl"
        ln -sfn "$(command -v rename.ul)" /tmp/toolchain-compat/rename
        rm -f "$toolchain_status" "$buildroot_root/output/host/bin/arm-linux-gcc"
        cat > /tmp/toolchain-compat/make <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
toolchain_target=false
if [[ "${1:-}" == V=1 && "${2:-}" == toolchain ]]; then
    toolchain_target=true
    rm -f /out/build/.toolchain-build.exitcode
    mkdir -p output
    if [[ ! -f output/.config ]]; then cp .config output/.config; fi
    sed -i 's|^BR2_PRIMARY_SITE=.*|BR2_PRIMARY_SITE="https://sources.buildroot.net"|' .config
    sed -i 's|^BR2_BACKUP_SITE=.*|BR2_BACKUP_SITE="https://sources.buildroot.net"|' .config
    mkdir -p package/m4
    cp /toolchain-build/m4-glibc-sigstksz.patch package/m4/0003-glibc-dynamic-sigstksz.patch
    for patch_file in package/uclibc/*.patch; do
        [[ -f "$patch_file" ]] || continue
        mv "$patch_file" "${patch_file}-"
    done
    m4_source=output/build/host-m4-1.4.18
    if [[ -f "$m4_source/lib/c-stack.c" ]] && grep -q 'HAVE_LIBSIGSEGV && SIGSTKSZ < 16384' "$m4_source/lib/c-stack.c"; then
        patch --directory="$m4_source" -p1 < package/m4/0003-glibc-dynamic-sigstksz.patch
        rm -f "$m4_source/.stamp_built"
    fi
    /usr/bin/make O=output olddefconfig
fi
status=0
/usr/bin/make "$@" || status=$?
if [[ "$toolchain_target" == true ]]; then
    printf '%s\n' "$status" > /out/build/.toolchain-build.exitcode
fi
exit "$status"
EOF
        chmod +x /tmp/toolchain-compat/make
        (cd "$build_workspace" && PATH="/tmp/toolchain-compat:$PATH" bash ./mktc.sh)
        rm -rf "$build_workspace"
    fi
    if [[ ! -f "$toolchain_status" || "$(cat "$toolchain_status")" != 0 ]]; then
        printf 'mktc.sh did not complete Buildroot toolchain successfully.\n' >&2
        exit 3
    fi
    if [[ ! -x "$compiler" ]]; then
        printf 'Build did not produce the expected uClibc EABI compiler: %s\n' "$compiler" >&2
        exit 4
    fi
    exit 0
fi
if [[ "$mode" != verify || ! -x "$compiler" || ! -f "$toolchain_status" || "$(cat "$toolchain_status")" != 0 ]]; then
    printf 'Expected a successful Buildroot toolchain before offline verification.\n' >&2
    exit 6
fi

printf 'Compiler version and target:\n'
"$compiler" --version | sed -n '1,2p'
"$compiler" -dumpmachine
probe_dir="$(mktemp -d /tmp/armv5-toolchain-probe.XXXXXX)"
trap 'rm -rf "$probe_dir"' EXIT
cat > "$probe_dir/probe.c" <<'EOF'
int main(void) { return 0; }
EOF
"$compiler" -c "$probe_dir/probe.c" -o "$probe_dir/probe.o"
readelf -h "$probe_dir/probe.o" | grep -E 'Class:|Data:|Machine:|Flags:'
printf '\nARM attributes:\n'
readelf -A "$probe_dir/probe.o"
if readelf -A "$probe_dir/probe.o" | grep -Eq 'Tag_CPU_arch: v7|Tag_CPU_arch: v8|Tag_ABI_VFP_args: VFP registers'; then
    printf 'Compiler output is not ARMv5 soft-float compatible.\n' >&2
    exit 4
fi
if ! readelf -A "$probe_dir/probe.o" | grep -Eiq 'Tag_CPU_arch: v5|Tag_CPU_name:.*arm926'; then
    printf 'Compiler output does not advertise the required ARMv5-class target.\n' >&2
    exit 5
fi

printf '\nCompiler sysroot: '
"$compiler" -print-sysroot
"$compiler" "$probe_dir/probe.c" -o "$probe_dir/probe"
printf '\nDynamically linked uClibc probe:\n'
readelf -l "$probe_dir/probe" | grep 'Requesting program interpreter'
readelf -d "$probe_dir/probe" | grep NEEDED
if ! readelf -l "$probe_dir/probe" | grep -Eiq 'ld-uClibc\.so'; then
    printf 'Dynamic executable does not request the uClibc loader.\n' >&2
    exit 7
fi
if ! readelf -d "$probe_dir/probe" | grep -Eiq 'Shared library: \[libc\.so\.0\]'; then
    printf 'Dynamic executable does not link against the uClibc libc soname.\n' >&2
    exit 8
fi
