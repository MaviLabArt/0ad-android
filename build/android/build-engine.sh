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
PREMAKE_ARGS=()
RUNTIME_COLLADA_ARGS=()
VCPKG_PKGCONFIG_DIR=""
SOURCE_TAG="${SOURCE_TAG:-}"

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

restore_dir_from_source_tag()
{
	local relpath="$1"

	if [[ -z "${SOURCE_TAG}" ]]; then
		return 1
	fi
	if ! command -v git >/dev/null 2>&1; then
		return 1
	fi
	if ! git rev-parse -q --verify "refs/tags/${SOURCE_TAG}" >/dev/null 2>&1; then
		return 1
	fi
	if ! git cat-file -e "${SOURCE_TAG}:${relpath}" 2>/dev/null; then
		return 1
	fi

	echo "Restoring ${relpath} from ${SOURCE_TAG}"
	mkdir -p "$(dirname "${relpath}")"
	git archive --format=tar "${SOURCE_TAG}" "${relpath}" | tar -xf -
	return 0
}

if [[ ! -d "${ROOT_DIR}/libraries/source/spidermonkey" ]]; then
	restore_dir_from_source_tag "libraries/source/spidermonkey" || true
fi
if [[ ! -d "${ROOT_DIR}/libraries/source/cpp-httplib" ]]; then
	restore_dir_from_source_tag "libraries/source/cpp-httplib" || true
fi
if [[ ! -d "${ROOT_DIR}/libraries/source/premake-core" ]]; then
	restore_dir_from_source_tag "libraries/source/premake-core" || true
fi

if [[ -f "${VCPKG_PKGCONFIG_DIR}/mozjs-128.pc" ]]; then
	echo "Using SpiderMonkey from VCPKG (${VCPKG_TRIPLET})"
	PREMAKE_ARGS+=(--with-system-mozjs)
else
	SPIDERMONKEY_DIR="${ROOT_DIR}/libraries/source/spidermonkey"
	SPIDERMONKEY_BUILD_SCRIPT="${SPIDERMONKEY_DIR}/build.sh"
	SPIDERMONKEY_INCLUDE_RELEASE="${SPIDERMONKEY_DIR}/include-release/js/RootingAPI.h"
	SPIDERMONKEY_RUST_LIB="${SPIDERMONKEY_DIR}/lib/libmozjs128-rust.a"
	SPIDERMONKEY_RELEASE_SO="${SPIDERMONKEY_DIR}/lib/libmozjs128-release.so"
	SPIDERMONKEY_RELEASE_A="${SPIDERMONKEY_DIR}/lib/libmozjs128-release.a"

	if [[ ! -d "${SPIDERMONKEY_DIR}" || ! -x "${SPIDERMONKEY_BUILD_SCRIPT}" ]]; then
		echo "SpiderMonkey is missing and no VCPKG mozjs-128 package was found."
		exit 1
	fi

	if [[ ! -f "${SPIDERMONKEY_INCLUDE_RELEASE}" || ! -f "${SPIDERMONKEY_RUST_LIB}" || ( ! -f "${SPIDERMONKEY_RELEASE_SO}" && ! -f "${SPIDERMONKEY_RELEASE_A}" ) ]]; then
		echo "SpiderMonkey artifacts not found, bootstrapping from ${SPIDERMONKEY_BUILD_SCRIPT}"
		SPIDERMONKEY_ANDROID_CONF_OPTS="--with-android-ndk=${NDK_ROOT} --with-android-toolchain=${NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_TAG}"
		(
			cd "${SPIDERMONKEY_DIR}"
			JOBS="-j${JOBS}" \
			CHOST="${HOST_TRIPLE}" \
			CTARGET="${HOST_TRIPLE}" \
			ANDROID_NDK_ROOT="${NDK_ROOT}" \
			CONF_OPTS="${SPIDERMONKEY_ANDROID_CONF_OPTS} ${CONF_OPTS:-}" \
			./build.sh
		)
	fi

	if [[ ! -f "${SPIDERMONKEY_INCLUDE_RELEASE}" || ! -f "${SPIDERMONKEY_RUST_LIB}" || ( ! -f "${SPIDERMONKEY_RELEASE_SO}" && ! -f "${SPIDERMONKEY_RELEASE_A}" ) ]]; then
		echo "SpiderMonkey bootstrap failed."
		exit 1
	fi
fi

if [[ -f "${VCPKG_TRIPLET_DIR}/include/httplib.h" ]]; then
	echo "Using cpp-httplib from VCPKG (${VCPKG_TRIPLET})"
	PREMAKE_ARGS+=(--with-system-cpp-httplib)
else
	CPP_HTTPLIB_BUILD_SCRIPT="${ROOT_DIR}/libraries/source/cpp-httplib/build.sh"
	CPP_HTTPLIB_HEADER="${ROOT_DIR}/libraries/source/cpp-httplib/include/httplib.h"
	if [[ ! -f "${CPP_HTTPLIB_HEADER}" ]]; then
		if [[ ! -x "${CPP_HTTPLIB_BUILD_SCRIPT}" ]]; then
			echo "cpp-httplib headers are missing and cannot be bootstrapped."
			exit 1
		fi
		echo "cpp-httplib headers not found, bootstrapping from ${CPP_HTTPLIB_BUILD_SCRIPT}"
		(
			cd "${ROOT_DIR}/libraries/source/cpp-httplib"
			JOBS="-j${JOBS}" ./build.sh
		)
	fi

	if [[ ! -f "${CPP_HTTPLIB_HEADER}" ]]; then
		echo "cpp-httplib bootstrap failed."
		exit 1
	fi
fi

PREMAKE_BIN="${ROOT_DIR}/libraries/source/premake-core/bin/premake5"
if [[ ! -x "${PREMAKE_BIN}" ]]; then
	PREMAKE_BUILD_SCRIPT="${ROOT_DIR}/libraries/source/premake-core/build.sh"
	if [[ -x "${PREMAKE_BUILD_SCRIPT}" ]]; then
		echo "premake5 not found, bootstrapping from ${PREMAKE_BUILD_SCRIPT}"
		(
			cd "${ROOT_DIR}/libraries/source/premake-core"
			JOBS="-j${JOBS}" MAKE="${MAKE_BIN}" ./build.sh
		)
	fi
fi

if [[ ! -x "${PREMAKE_BIN}" ]]; then
	if command -v premake5 >/dev/null 2>&1; then
		echo "Using system premake5"
		PREMAKE_ARGS+=(--with-system-premake5)
	else
		echo "Could not find or build premake5."
		exit 1
	fi
fi

if [[ -d "${ROOT_DIR}/libraries/source/fcollada/src" ]]; then
	(
		cd "${ROOT_DIR}/libraries/source/fcollada"
		JOBS="-j${JOBS}" MAKE="${MAKE_BIN}" ./build.sh
	)
else
	echo "FCollada sources not present; disabling runtime Collada conversion."
	RUNTIME_COLLADA_ARGS+=(--without-runtime-collada)
fi

# Ensure linker can resolve -lSDL2 during engine link step.
SDL_PREBUILT_LIB="${ROOT_DIR}/build/android/prebuilt-libs/${ANDROID_ABI}/libSDL2.so"
if [[ -f "${SDL_PREBUILT_LIB}" ]]; then
	cp -f "${SDL_PREBUILT_LIB}" "${ROOT_DIR}/binaries/system/libSDL2.so"
fi

# Keep Android builds lean to avoid unavailable desktop-only deps.
./build/workspaces/update-workspaces.sh \
	"${PREMAKE_ARGS[@]}" \
	--android \
	--gles \
	--without-atlas \
	--without-tests \
	--without-lobby \
	--without-nvtt \
	--without-miniupnpc \
	--without-dap-interface \
	"${RUNTIME_COLLADA_ARGS[@]}" \
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
