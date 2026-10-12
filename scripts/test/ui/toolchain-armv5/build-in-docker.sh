#!/usr/bin/env bash
set -Eeuo pipefail

readonly repo_root="$(git rev-parse --show-toplevel)"
readonly toolchain_dir="$repo_root/scripts/test/ui/toolchain-armv5"
readonly docker_context="${DOCKER_CONTEXT:-docker-dev}"
readonly image_tag="alt-f-armv5-toolchain:buildroot-2019.02.8"
readonly volume_name="alt-f-armv5-toolchain-buildroot-2019.02.8"
readonly host_uid="$(id -u)"
readonly host_gid="$(id -g)"

fail() {
    printf 'ARMv5 toolchain preflight failed: %s\n' "$1" >&2
    exit 2
}

[[ "$docker_context" == docker-dev ]] || fail 'only docker-dev is permitted'
[[ -f "$repo_root/mktc.sh" ]] || fail 'mktc.sh is missing'
[[ -f "$repo_root/local/buildroot-2019.02.8.config" ]] || fail 'Buildroot config is missing'
[[ -f "$repo_root/local/uclibc-1.0.31.config" ]] || fail 'uClibc config is missing'
[[ -f "$repo_root/local/dns325/dns325.config" ]] || fail 'DNS-325 board config is missing'

grep -q '^BR2_arm=y$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'not an ARM Buildroot config'
grep -q '^BR2_arm926t=y$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'Buildroot CPU is not ARM926T'
grep -q '^BR2_GCC_TARGET_CPU="arm926ej-s"$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'Buildroot CPU target is not ARM926EJ-S'
grep -q '^BR2_GCC_TARGET_FLOAT_ABI="soft"$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'Buildroot float ABI is not soft'
grep -q '^BR2_ARM_EABI=y$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'Buildroot EABI is disabled'
grep -q '^BR2_TOOLCHAIN_USES_UCLIBC=y$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'Buildroot is not using uClibc'
grep -q '^BR2_GCC_VERSION="7.4.0"$' "$repo_root/local/buildroot-2019.02.8.config" || fail 'unexpected GCC version'
grep -q '^TARGET_ARCH="arm"$' "$repo_root/local/uclibc-1.0.31.config" || fail 'uClibc target architecture is not ARM'
grep -q '^CONFIG_ARM_EABI=y$' "$repo_root/local/uclibc-1.0.31.config" || fail 'uClibc EABI is disabled'
grep -q '^UCLIBC_HAS_SOFT_FLOAT=y$' "$repo_root/local/uclibc-1.0.31.config" || fail 'uClibc soft-float is disabled'
grep -q '^BR2_GCC_TARGET_ARCH="armv5te"$' "$repo_root/local/dns325/dns325.config" || fail 'DNS-325 target is not ARMv5TE'

if ! docker --context "$docker_context" context inspect >/dev/null 2>&1; then
    fail 'docker-dev context is unavailable'
fi

printf 'Building cached toolchain image from an explicit source-only context.\n'
tar -cf - \
    -C "$toolchain_dir" Dockerfile run-toolchain.sh m4-glibc-sigstksz.patch \
    -C "$repo_root" mktc.sh local/buildroot-2019.02.8.config local/uclibc-1.0.31.config \
    | docker --context "$docker_context" build --network host --tag "$image_tag" -

docker --context "$docker_context" volume create "$volume_name" >/dev/null

docker --context "$docker_context" run --rm --network none \
    --volume "$volume_name:/out" --entrypoint /bin/bash "$image_tag" \
    -euc "mkdir -p /out/build/dl && chown -R '$host_uid:$host_gid' /out"

printf 'Building the ARMv5/uClibc toolchain in its persistent Docker volume.\n'
docker --context "$docker_context" run --rm --network host \
    --user "$host_uid:$host_gid" --volume "$volume_name:/out" \
    "$image_tag" build

printf 'Verifying compiler and ELF attributes offline.\n'
docker --context "$docker_context" run --rm --network none \
    --user "$host_uid:$host_gid" --volume "$volume_name:/out" \
    "$image_tag" verify
