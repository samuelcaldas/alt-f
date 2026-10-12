#!/usr/bin/env bash
set -Eeuo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repo_root="$(cd "$script_dir/../../../.." && pwd)"
readonly docker_context="${DOCKER_CONTEXT:-docker-dev}"
readonly sdk_volume="alt-f-armv5-toolchain-ubuntu2004"
readonly firmware_volume="alt-f-dns325-firmware-preflight-ubuntu2004"
readonly image_tag="alt-f-dns325-firmware-preflight:ubuntu-20.04"
readonly temporary_context="$(mktemp -d /tmp/alt-f-firmware-context.XXXXXX)"
trap 'rm -rf "$temporary_context"' EXIT

fail() {
    printf 'Firmware build preflight failed: %s\n' "$1" >&2
    exit 2
}

[[ "$docker_context" == docker-dev ]] || fail 'only docker-dev is permitted'
[[ -f "$repo_root/exports" && -f "$repo_root/local/dns325/dns325.config" ]] || fail 'firmware source inputs are missing'
grep -q '^BR2_PROJECT="dns325"$' "$repo_root/local/dns325/dns325.config" || fail 'DNS-325 project config is invalid'
grep -q '^BR2_arm=y$' "$repo_root/local/dns325/dns325.config" || fail 'DNS-325 config is not ARM'
grep -q '^BR2_ARM_EABI=y$' "$repo_root/local/dns325/dns325.config" || fail 'DNS-325 config is not EABI'
grep -q '^BR2_TOOLCHAIN_EXTERNAL=y$' "$repo_root/local/dns325/dns325.config" || fail 'DNS-325 config does not select an external toolchain'
grep -q '^BR2_TOOLCHAIN_EXTERNAL_PREFIX="arm-buildroot-linux-uclibcgnueabi"$' "$repo_root/local/dns325/dns325.config" || fail 'DNS-325 external compiler prefix does not match the validated SDK'
docker --context "$docker_context" context inspect >/dev/null 2>&1 || fail 'docker-dev context is unavailable'
docker --context "$docker_context" volume inspect "$sdk_volume" >/dev/null 2>&1 || fail 'validated SDK volume is unavailable'

printf 'Preparing a source-only disposable firmware build context.\n'
tar -cf "$temporary_context/source.tar" \
    --exclude=.git --exclude=.env --exclude='.env.*' --exclude=.remember \
    --exclude=.claude --exclude=scratch --exclude=tmp --exclude=.playwright-mcp \
    --exclude=.superpowers --exclude=.config --exclude=.config.cmd \
    --exclude=build --exclude='build_*' --exclude='project_*' \
    --exclude='toolchain_*' --exclude=binaries --exclude=dl \
    --exclude=output --exclude='*/.git' --exclude='*/.env' \
    --exclude='*/.env.*' --exclude='*/.remember' --exclude='*/.claude' \
    --exclude='*/scratch' --exclude='*/.playwright-mcp' \
    -C "$repo_root" .
if tar -tf "$temporary_context/source.tar" | grep -Eq '(^|/)(\.git|\.env(\..*)?|\.remember|\.claude|scratch|\.playwright-mcp)(/|$)'; then
    fail 'source archive contains an excluded secret or scratch path'
fi

tar -cf - -C "$script_dir" firmware.Dockerfile firmware-run.sh \
    -C "$temporary_context" source.tar \
    | docker --context "$docker_context" build --network host \
        --file firmware.Dockerfile --tag "$image_tag" -

docker --context "$docker_context" volume create "$firmware_volume" >/dev/null
printf 'Running DNS-325 exports/config preflight, then single-job firmware make.\n'
printf 'SDK volume is read-only; firmware output uses %s.\n' "$firmware_volume"
docker --context "$docker_context" run --rm --network host \
    --env TZ=America/Sao_Paulo \
    --volume "$sdk_volume:/out:ro" \
    --volume "$firmware_volume:/firmware" \
    "$image_tag"
