#!/bin/bash

set -eu

declare -r workdir="${PWD}"

declare -r revision="$(git rev-parse --short HEAD)"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.3.0'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.1'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.42'

declare gcc_directory=''

function setup_gcc_source() {
	
	local gcc_version=''
	local gcc_url=''
	local gcc_tarball=''
	local tgt="${1}"
	
	declare -r tgt
	
	if [ "${tgt}" = 'hpcsh' ] || [ "${tgt}" = 'emips' ]; then
		gcc_version='12'
		gcc_directory='/tmp/gcc-12.3.0'
		gcc_url='https://ftp.gnu.org/gnu/gcc/gcc-12.3.0/gcc-12.3.0.tar.xz'
	else
		gcc_version='14'
		gcc_directory='/tmp/gcc-14.1.0'
		gcc_url='https://ftp.gnu.org/gnu/gcc/gcc-14.1.0/gcc-14.1.0.tar.xz'
	fi
	
	gcc_tarball="/tmp/gcc-${gcc_version}.tar.xz"
	
	declare -r gcc_version
	declare -r gcc_url
	declare -r gcc_tarball
	
	if ! [ -f "${gcc_tarball}" ]; then
		wget --no-verbose "${gcc_url}" --output-document="${gcc_tarball}"
		tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"
	fi
	
	[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"
	
	if ! [ -f "${gcc_directory}/patched" ]; then
		if (( gcc_version >= 14 )); then
			patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Disable-libfunc-support-for-hppa-unknown-netbsd.patch"
			patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Fix-issues-with-fenv.patch"
		fi
		
		touch "${gcc_directory}/patched"
	fi
	
}

declare -r optflags='-Os'
declare -r linkflags='-Wl,-s'

declare -r max_jobs="$(($(nproc) * 17))"

declare build_type="${1}"

if [ -z "${build_type}" ]; then
	build_type='native'
fi

declare is_native='0'

if [ "${build_type}" == 'native' ]; then
	is_native='1'
fi

declare OBGGCC_TOOLCHAIN='/tmp/obggcc-toolchain'
declare CROSS_COMPILE_TRIPLET=''

declare cross_compile_flags=''

if ! (( is_native )); then
	source "./submodules/obggcc/toolchains/${build_type}.sh"
	cross_compile_flags+="--host=${CROSS_COMPILE_TRIPLET}"
fi

if ! [ -f "${gmp_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz' --output-document="${gmp_tarball}"
	tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz' --output-document="${mpfr_tarball}"
	tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
	tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz' --output-document="${binutils_tarball}"
	tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"
	
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/patches/0001-Revert-gold-Use-char16_t-char32_t-instead-of-uint16_.patch"
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/patches/0001-Disable-annoying-local-symbol-warning-on-bfd-linker.patch"
fi

declare -r toolchain_directory="/tmp/dakini"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"
rm --force --recursive ./*

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"
rm --force --recursive ./*

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"
rm --force --recursive ./*

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

declare -r targets=(
	'hpcsh'
	'vax'
	'emips'
	'evbppc'
	'hppa'
	'amd64'
	'i386'
	'alpha'
	'sparc'
	'sparc64'
)

for target in "${targets[@]}"; do
	declare url="https://archive.netbsd.org/pub/NetBSD-archive/NetBSD-8.0/${target}/binary/sets"
	
	case "${target}" in
		amd64)
			declare triplet='x86_64-unknown-netbsd';;
		i386)
			declare triplet='i386-unknown-netbsdelf';;
		emips)
			declare triplet='mips-unknown-netbsd';;
		alpha)
			declare triplet='alpha-unknown-netbsd';;
		hppa)
			declare triplet='hppa-unknown-netbsd';;
		sparc)
			declare triplet='sparc-unknown-netbsdelf';;
		sparc64)
			declare triplet='sparc64-unknown-netbsd';;
		vax)
			declare triplet='vax-unknown-netbsdelf';;
		hpcsh)
			declare triplet='shle-unknown-netbsdelf';;
		evbppc)
			declare triplet='powerpc-unknown-netbsd';;
	esac
	
	declare base_url="${url}/base.tgz"
	declare comp_url="${url}/comp.tgz"
	
	declare base_output="/tmp/$(basename "${base_url}")"
	declare comp_output="/tmp/$(basename "${comp_url}")"
	
	curl \
		--url "${base_url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--verbose \
		--silent \
		--output "${base_output}"
	
	curl \
		--url "${comp_url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--verbose \
		--silent \
		--output "${comp_output}"
	
	cd "${binutils_directory}/build"
	rm --force --recursive ./*
	
	../configure \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld \
		--enable-lto \
		--disable-gprofng \
		--with-static-standard-libraries \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		${cross_compile_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		LDFLAGS="${linkflags}"
	
	make all --jobs
	make install
	
	tar --directory="${toolchain_directory}/${triplet}" --strip=2 --extract --file="${base_output}" './usr/lib' './usr/include'
	tar --directory="${toolchain_directory}/${triplet}" --extract --file="${base_output}"  './lib'
	tar --directory="${toolchain_directory}/${triplet}" --strip=2 --extract --file="${comp_output}" './usr/lib' './usr/include'
	
	# Update permissions
	while read name; do
		if [ -f "${name}" ]; then
			chmod 644 "${name}"
		elif [ -d "${name}" ]; then
			chmod 755 "${name}"
		fi
	done <<< "$(find "${toolchain_directory}/${triplet}/include" "${toolchain_directory}/${triplet}/lib")"
	
	setup_gcc_source "${target}"
	
	cd "${gcc_directory}/build"
	
	rm --force --recursive ./*
	
	declare extra_configure_flags=''
	
	if [ "${target}" != 'hppa' ]; then
		extra_configure_flags+='--enable-gnu-unique-object '
	fi
	
	if [ "${target}" == 'emips' ]; then
		extra_configure_flags+='--with-float=soft '
	fi
	
	declare CFLAGS_FOR_TARGET="${optflags} ${linkflags}"
	declare CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}"
	
	if [ "${target}" == 'hpcsh' ]; then
		CXXFLAGS_FOR_TARGET+=' -include sh3/fenv.h'
	fi
	
	../configure \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style='sysv' \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-bugurl='https://github.com/AmanoTeam/Dakini/issues' \
		--with-gcc-major-version-only \
		--with-pkgversion="Dakini v0.5-${revision}" \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-native-system-header-dir='/include' \
		--enable-__cxa_atexit \
		--enable-cet='auto' \
		--enable-checking='release' \
		--enable-clocale='gnu' \
		--enable-default-ssp \
		--enable-gnu-indirect-function \
		--enable-libstdcxx-backtrace \
		--enable-link-serialization='1' \
		--enable-linker-build-id \
		--enable-lto \
		--enable-plugin \
		--enable-shared \
		--enable-threads='posix' \
		--enable-languages='c,c++' \
		--enable-libssp \
		--enable-ld \
		--enable-gold \
		--disable-multilib \
		--disable-libstdcxx-pch \
		--disable-werror \
		--disable-bootstrap \
		--disable-nls \
		--without-headers \
		${cross_compile_flags} \
		${extra_configure_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		LDFLAGS="-Wl,-rpath-link,${OBGGCC_TOOLCHAIN}/${CROSS_COMPILE_TRIPLET}/lib ${linkflags}"
	
	LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make \
		CFLAGS_FOR_TARGET="${CFLAGS_FOR_TARGET}" \
		CXXFLAGS_FOR_TARGET="${CXXFLAGS_FOR_TARGET}" \
		all --jobs="${max_jobs}"
	make install
	
	cd "${toolchain_directory}/${triplet}/bin"
	
	for name in *; do
		rm "${name}"
		ln -s "../../bin/${triplet}-${name}" "${name}"
	done
	
	rm --recursive "${toolchain_directory}/share"
	rm --recursive "${toolchain_directory}/lib/gcc/${triplet}/"*"/include-fixed"
	
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
	
	# Strip debug symbols from shared libraries
	while read name; do
		name="$(realpath "${name}")"
		
		if [[ "$(file --brief --mime-type "${name}")" != 'application/x-sharedlib' ]]; then
			continue
		fi
		
		if (( is_native )); then
			"${toolchain_directory}/bin/${triplet}-strip" "${name}"
		else
			"${DAKINI_HOME}/bin/${triplet}-strip" "${name}"
		fi
	done <<< "$(find "${toolchain_directory}/${triplet}/lib" -wholename '*.so')"
	
	# Fix some libraries not being found during linkage
	if [ "${target}" == 'hpcsh' ]; then
		cd "${toolchain_directory}/${triplet}/lib"
		
		for name in $(ls '!m3'); do
			if ! [ -f "./${name}" ]; then
				ln --symbolic './!m3/'"${name}" "./${name}"
			fi
		done
	fi
done
