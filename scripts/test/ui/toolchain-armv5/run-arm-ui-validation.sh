#!/usr/bin/env bash
set -Eeuo pipefail

readonly repo_root="$(git rev-parse --show-toplevel)"
readonly helper_dir="$repo_root/scripts/test/ui/toolchain-armv5"
readonly docker_context="${DOCKER_CONTEXT:-docker-dev}"
readonly toolchain_image=alt-f-armv5-toolchain:buildroot-2019.02.8
readonly validation_image=alt-f-armv5-ui-validation:buildroot-2019.02.8
readonly toolchain_volume=alt-f-armv5-toolchain-buildroot-2019.02.8
readonly ddns_baseline_sha256=35d7c19e6d63d6d4cc999170ef45bb801535ea0116dc0423a8a19080b2307b04

fail() {
    printf 'ARM UI validation preflight failed: %s\n' "$1" >&2
    exit 2
}

[[ "$docker_context" == docker-dev ]] || fail 'only docker-dev is permitted'
[[ -f "$repo_root/local/pkgs/busybox-1.20.2.config" ]] || fail 'BusyBox config is missing'
[[ -d "$repo_root/package/busybox" ]] || fail 'BusyBox patch directory is missing'
[[ -d "$repo_root/customroot/usr/www/cgi-bin" ]] || fail 'CGI source directory is missing'
readonly ddns_path=customroot/usr/www/cgi-bin/ddns_proc.cgi
readonly baseline_hash="$(git show "HEAD:$ddns_path" | sha256sum | awk '{print $1}')"
readonly working_hash="$(sha256sum "$repo_root/$ddns_path" | awk '{print $1}')"
[[ "$baseline_hash" == "$ddns_baseline_sha256" && "$working_hash" == "$ddns_baseline_sha256" ]] \
    || fail 'ddns_proc.cgi no longer matches the hash-checked baseline defect'
docker --context "$docker_context" image inspect "$toolchain_image" >/dev/null 2>&1 || fail 'validated ARMv5 toolchain image is missing'
docker --context "$docker_context" volume inspect "$toolchain_volume" >/dev/null 2>&1 || fail 'ARMv5 toolchain volume is missing'

context_dir="$(mktemp -d /tmp/arm-ui-docker-context.XXXXXX)"
source_context="$(mktemp -d /tmp/arm-ui-source-context.XXXXXX)"
readonly source_volume="alt-f-armv5-ui-source-$$"
readonly download_volume="alt-f-armv5-busybox-source-$$"
trap 'rm -rf "$context_dir" "$source_context"; docker --context "$docker_context" volume rm "$source_volume" "$download_volume" >/dev/null 2>&1 || true' EXIT
cp "$helper_dir/Dockerfile.ui-validation" "$context_dir/Dockerfile"
cp "$helper_dir/validate-arm-ui.sh" "$context_dir/validate-arm-ui.sh"

printf 'Building ARM UI validation image from helper-only context.\n'
docker --context "$docker_context" build --network host \
    --tag "$validation_image" "$context_dir"

mkdir -p "$source_context/src/cgi-bin" "$source_context/src/busybox-patches" "$source_context/src/www"
cp -a "$repo_root/customroot/usr/www/cgi-bin/." "$source_context/src/cgi-bin/"
cp "$repo_root/local/pkgs/busybox-1.20.2.config" "$source_context/src/busybox-1.20.2.config"
cp -a "$repo_root/package/busybox/." "$source_context/src/busybox-patches/"
cp -a "$repo_root/customroot/usr/www/scripts" "$source_context/src/www/"

docker --context "$docker_context" volume create "$source_volume" >/dev/null
printf 'Transferring selected repository inputs as source-only tar over Docker stdin.\n'
tar -cf - -C "$source_context/src" . \
    | docker --context "$docker_context" run --rm --interactive --network none \
        --mount "type=volume,source=$source_volume,target=/repo-source" \
        --entrypoint /bin/tar "$validation_image" -xf - -C /repo-source

docker --context "$docker_context" volume create "$download_volume" >/dev/null
printf 'Downloading the requested BusyBox archive into a disposable source volume.\n'
docker --context "$docker_context" run --rm --network host \
    --mount "type=volume,source=$download_volume,target=/download" \
    --entrypoint /bin/bash "$validation_image" -euc \
    'curl --fail --location --silent --show-error https://busybox.net/downloads/busybox-1.20.2.tar.bz2 --output /download/busybox-1.20.2.tar.bz2 && (cd /download && sha256sum busybox-1.20.2.tar.bz2 > busybox-1.20.2.tar.bz2.sha256)'

printf 'Running offline ARMv5 BusyBox and UI helper validation with read-only volumes.\n'
docker --context "$docker_context" run --rm --network none \
    --tmpfs /tmp:rw,exec,size=1g \
    --mount "type=volume,source=$download_volume,target=/input,readonly" \
    --mount "type=volume,source=$source_volume,target=/src,readonly" \
    --mount "type=volume,source=$toolchain_volume,target=/out,readonly" \
    "$validation_image"
