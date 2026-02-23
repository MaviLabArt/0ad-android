#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NDK_ROOT="${ANDROID_NDK_ROOT:-${NDK_ROOT:-}}"
API_LEVEL="${ANDROID_API:-24}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
MAKE_BIN="${MAKE_BIN:-make}"

if command -v nproc >/dev/null 2>&1; then
	JOBS_DEFAULT="$(nproc)"
else
	JOBS_DEFAULT="4"
fi
JOBS="${JOBS:-${JOBS_DEFAULT}}"

if [[ -z "${NDK_ROOT}" ]]; then
	echo "Set ANDROID_NDK_ROOT (or NDK_ROOT) to your Android NDK path."
	exit 1
fi

case "${ANDROID_ABI}" in
	arm64-v8a)
		CLANG_TRIPLE="aarch64-linux-android"
		HOST_TRIPLE="aarch64-linux-android"
		VCPKG_DEFAULT_TRIPLET="arm64-android"
		;;
	armeabi-v7a)
		CLANG_TRIPLE="armv7a-linux-androideabi"
		HOST_TRIPLE="arm-linux-androideabi"
		VCPKG_DEFAULT_TRIPLET="arm-neon-android"
		;;
	x86_64)
		CLANG_TRIPLE="x86_64-linux-android"
		HOST_TRIPLE="x86_64-linux-android"
		VCPKG_DEFAULT_TRIPLET="x64-android"
		;;
	x86)
		CLANG_TRIPLE="i686-linux-android"
		HOST_TRIPLE="i686-linux-android"
		VCPKG_DEFAULT_TRIPLET="x86-android"
		;;
	*)
		echo "Unsupported ANDROID_ABI: ${ANDROID_ABI}"
		exit 1
		;;
esac

VCPKG_TRIPLET="${VCPKG_TRIPLET:-${VCPKG_DEFAULT_TRIPLET}}"

case "$(uname -s)" in
	Linux)
		HOST_TAG="linux-x86_64"
		;;
	Darwin)
		if [[ "$(uname -m)" == "arm64" ]]; then
			HOST_TAG="darwin-arm64"
		else
			HOST_TAG="darwin-x86_64"
		fi
		;;
	*)
		echo "Unsupported host OS for this helper script: $(uname -s)"
		exit 1
		;;
esac

TOOLCHAIN="${NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"
if [[ ! -d "${TOOLCHAIN}" ]]; then
	echo "Could not find toolchain binaries at ${TOOLCHAIN}"
	exit 1
fi

export AR="${TOOLCHAIN}/llvm-ar"
export CC="${TOOLCHAIN}/${CLANG_TRIPLE}${API_LEVEL}-clang"
export CXX="${TOOLCHAIN}/${CLANG_TRIPLE}${API_LEVEL}-clang++"
export LD="${TOOLCHAIN}/ld.lld"
export NM="${TOOLCHAIN}/llvm-nm"
export RANLIB="${TOOLCHAIN}/llvm-ranlib"
export STRIP="${TOOLCHAIN}/llvm-strip"
export HOSTTYPE="${HOST_TRIPLE}"

# Android 16 KB page-size compatibility for shared objects.
ANDROID_PAGE_SIZE_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
if [ -n "${LDFLAGS:-}" ]; then
	export LDFLAGS="${LDFLAGS} ${ANDROID_PAGE_SIZE_LDFLAGS}"
else
	export LDFLAGS="${ANDROID_PAGE_SIZE_LDFLAGS}"
fi

VCPKG_TRIPLET_DIR="${ROOT_DIR}/.cache-vcpkg/installed/${VCPKG_TRIPLET}"
if [[ -d "${VCPKG_TRIPLET_DIR}" ]]; then
	if [ -n "${CPPFLAGS:-}" ]; then
		export CPPFLAGS="${CPPFLAGS} -I${VCPKG_TRIPLET_DIR}/include"
	else
		export CPPFLAGS="-I${VCPKG_TRIPLET_DIR}/include"
	fi
	export LDFLAGS="${LDFLAGS} -L${VCPKG_TRIPLET_DIR}/lib"

	VCPKG_PKGCONFIG_DIR="${VCPKG_TRIPLET_DIR}/lib/pkgconfig"
	if [[ -d "${VCPKG_PKGCONFIG_DIR}" ]]; then
		if [ -n "${PKG_CONFIG_PATH:-}" ]; then
			export PKG_CONFIG_PATH="${VCPKG_PKGCONFIG_DIR}:${PKG_CONFIG_PATH}"
		else
			export PKG_CONFIG_PATH="${VCPKG_PKGCONFIG_DIR}"
		fi
		export PKG_CONFIG_LIBDIR="${VCPKG_PKGCONFIG_DIR}"
	fi
fi

cd "${ROOT_DIR}"

if [[ -d "${ROOT_DIR}/libraries/source/fcollada/src" ]]; then
	(
		cd "${ROOT_DIR}/libraries/source/fcollada"
		JOBS="-j${JOBS}" MAKE="${MAKE_BIN}" ./build.sh
	)
fi

# Ensure linker can resolve -lSDL2 during engine link step.
SDL_PREBUILT_LIB="${ROOT_DIR}/build/android/prebuilt-libs/${ANDROID_ABI}/libSDL2.so"
if [[ -f "${SDL_PREBUILT_LIB}" ]]; then
	cp -f "${SDL_PREBUILT_LIB}" "${ROOT_DIR}/binaries/system/libSDL2.so"
fi

# Keep Android builds lean to avoid unavailable desktop-only deps.
./build/workspaces/update-workspaces.sh \
	--android \
	--gles \
	--without-atlas \
	--without-tests \
	--without-lobby \
	--without-nvtt \
	--without-miniupnpc \
	--without-dap-interface \
	"$@"
"${MAKE_BIN}" -C build/workspaces/gcc -j"${JOBS}" config="${BUILD_CONFIG}"

ICUDATA_ARCHIVE="${VCPKG_TRIPLET_DIR}/lib/libicudata.a"
ICUDATA_SHARED="${ROOT_DIR}/binaries/system/libicudata.so"
if [[ -f "${ICUDATA_ARCHIVE}" ]]; then
	"${CC}" \
		-shared \
		-Wl,-soname=libicudata.so \
		${ANDROID_PAGE_SIZE_LDFLAGS} \
		-Wl,--whole-archive "${ICUDATA_ARCHIVE}" -Wl,--no-whole-archive \
		-o "${ICUDATA_SHARED}"
	echo "Built ${ICUDATA_SHARED}"
fi
