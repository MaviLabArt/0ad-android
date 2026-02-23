#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${1:-${SCRIPT_DIR}/../../../binaries/system}"
ABI="${ABI:-arm64-v8a}"
DEST_DIR="${SCRIPT_DIR}/app/src/main/jniLibs/${ABI}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
	echo "Source directory does not exist: ${SOURCE_DIR}"
	exit 1
fi

mkdir -p "${DEST_DIR}"
find "${DEST_DIR}" -maxdepth 1 \( -type f -o -type l \) -name '*.so*' -delete

copied=0
while IFS= read -r sofile; do
	base="$(basename "${sofile}")"
	if [[ "${base}" == libSDL2.so* ]]; then
		continue
	fi

	cp -fL "${sofile}" "${DEST_DIR}/"
	copied=1
done < <(find "${SOURCE_DIR}" -maxdepth 1 \( -type f -o -type l \) -name '*.so*' | sort)

if [[ "${copied}" -eq 0 ]]; then
	echo "No .so files found in ${SOURCE_DIR}"
	exit 1
fi

if [[ ! -f "${DEST_DIR}/libpyrogenesis.so" && ! -f "${DEST_DIR}/libpyrogenesis_dbg.so" ]]; then
	echo "Warning: libpyrogenesis(.so/_dbg.so) was not copied to ${DEST_DIR}"
fi

echo "Copied native libraries to ${DEST_DIR}"
