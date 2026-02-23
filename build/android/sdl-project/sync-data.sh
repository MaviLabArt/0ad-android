#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${1:-${SCRIPT_DIR}/../../../binaries/data}"
PACKAGE_NAME="${PACKAGE_NAME:-com.wildfiregames.zeroad}"
ADB_BIN="${ADB_BIN:-adb}"
DEVICE_ROOT_INTERNAL="/data/user/0/${PACKAGE_NAME}/files/0ad"
DEVICE_ROOT_EXTERNAL="/sdcard/Android/data/${PACKAGE_NAME}/files/0ad"
DEVICE_ROOT="${DEVICE_ROOT:-${DEVICE_ROOT_INTERNAL}}"

if [[ ! -d "${DATA_DIR}" ]]; then
	echo "Data directory does not exist: ${DATA_DIR}"
	exit 1
fi

if [[ "${DEVICE_ROOT}" == "${DEVICE_ROOT_INTERNAL}" ]] && "${ADB_BIN}" shell "run-as '${PACKAGE_NAME}' true" >/dev/null 2>&1; then
	echo "Syncing data into internal app storage via run-as: ${DEVICE_ROOT}/data"
	"${ADB_BIN}" shell "run-as '${PACKAGE_NAME}' sh -c 'rm -rf files/0ad/data && mkdir -p files/0ad/data'"
	tar -C "${DATA_DIR}" -cf - . | "${ADB_BIN}" shell -T "run-as '${PACKAGE_NAME}' sh -c 'cd files/0ad/data && tar -xf - 2>/dev/null'"
	echo "Data synced to ${DEVICE_ROOT}/data"
	exit 0
fi

if [[ "${DEVICE_ROOT}" == "${DEVICE_ROOT_INTERNAL}" ]]; then
	echo "run-as unavailable for ${PACKAGE_NAME}; falling back to external storage path."
	DEVICE_ROOT="${DEVICE_ROOT_EXTERNAL}"
fi

"${ADB_BIN}" shell "mkdir -p '${DEVICE_ROOT}/data'"
"${ADB_BIN}" push "${DATA_DIR}" "${DEVICE_ROOT}/"

echo "Data synced to ${DEVICE_ROOT}/data"
