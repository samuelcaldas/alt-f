#!/bin/sh
# Build and run development-only UI suites on the remote docker-dev context.
set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/../../.." && pwd)
DOCKER_CONTEXT=docker-dev
BUILD_NETWORK=${ALT_F_BUILD_NETWORK:-host}
SUITE=${1:-all}
if test "$SUITE" = --suite; then SUITE=${2:?Missing suite name}; fi
case "$SUITE" in all|static|render|browser|budget) ;; *) echo 'Usage: run_ui_checks.sh [--suite] all|static|render|browser|budget' >&2; exit 2 ;; esac

docker context inspect "$DOCKER_CONTEXT" >/dev/null

# Supply the build context explicitly; remote Docker cannot mount local paths.
build_checks() {
	docker --context "$DOCKER_CONTEXT" build --network "$BUILD_NETWORK" --target checks -t alt-f-ui-checks -f "$SCRIPT_DIRECTORY/Dockerfile" "$REPOSITORY"
}

# Run only shared render helpers and source checks, never arbitrary NAS CGI.
run_checks() {
	docker --context "$DOCKER_CONTEXT" run --rm --network none --cap-drop=ALL --security-opt=no-new-privileges alt-f-ui-checks python -m unittest "$@" -v
}

# Fetch artifacts from the remote daemon rather than binding the local directory.
run_browser() {
	docker --context "$DOCKER_CONTEXT" build --network "$BUILD_NETWORK" --target browser -t alt-f-ui-browser -f "$SCRIPT_DIRECTORY/Dockerfile" "$REPOSITORY"
	container=$(docker --context "$DOCKER_CONTEXT" create --network none --cap-drop=ALL --security-opt=no-new-privileges alt-f-ui-browser)
	trap 'docker --context "$DOCKER_CONTEXT" rm "$container" >/dev/null' EXIT HUP INT TERM
	result=0
	docker --context "$DOCKER_CONTEXT" start -a "$container" || result=$?
	mkdir -p "$REPOSITORY/.playwright-mcp"
	docker --context "$DOCKER_CONTEXT" cp "$container:/tests/.playwright-mcp/." "$REPOSITORY/.playwright-mcp/" || result=1
	return "$result"
}

case "$SUITE" in
	static) build_checks; run_checks test_static ;;
	render) build_checks; run_checks test_render test_auth test_compatibility ;;
	budget) build_checks; run_checks test_budget ;;
	browser) run_browser ;;
	all) build_checks; run_checks discover; run_browser ;;
esac
