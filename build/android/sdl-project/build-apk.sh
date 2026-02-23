#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 0 ]]; then
	SDL2_DIR="$1"
	shift
else
	SDL2_DIR="${SDL2_SOURCE_DIR:-}"
fi

if [[ -z "${SDL2_DIR}" ]]; then
	echo "Usage: $0 /absolute/path/to/SDL [extra-gradle-args...]"
	echo "Or set SDL2_SOURCE_DIR in the environment."
	exit 1
fi

if [[ ! -f "${SDL2_DIR}/Android.mk" ]]; then
	echo "SDL2_SOURCE_DIR does not look like an SDL2 source tree: ${SDL2_DIR}"
	exit 1
fi

SDL2_DIR="$(cd "${SDL2_DIR}" && pwd)"

# SDL2's Android.mk imports android/cpufeatures in a way that breaks with
# modern NDK module layout. Keep this patch local and idempotent.
if grep -q 'LOCAL_STATIC_LIBRARIES := cpufeatures' "${SDL2_DIR}/Android.mk"; then
	sed -i \
		-e '/LOCAL_STATIC_LIBRARIES := cpufeatures/d' \
		-e '/$(call import-module,android\/cpufeatures)/d' \
		"${SDL2_DIR}/Android.mk"
fi

GRADLE_BIN="${GRADLE_BIN:-gradle}"

cd "${SCRIPT_DIR}"

"${GRADLE_BIN}" :app:assembleDebug \
	-PSDL2_SOURCE_DIR="${SDL2_DIR}" \
	"$@"
