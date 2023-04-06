#!/bin/bash

set -e
set -u

declare -r revision="$(git rev-parse --short HEAD)"

declare -r toolchain_tarball="${PWD}/netbsd-cross.tar.xz"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.0'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.40'

declare -r gcc_tarball='/tmp/gcc.tar.xz'
declare -r gcc_directory='/tmp/gcc-12.2.0'

declare -r cflags='-Os -s -DNDEBUG'

if ! [ -f "${gmp_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz' --output-document="${gmp_tarball}"
	tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz' --output-document="${mpfr_tarball}"
	tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
	tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz' --output-document="${binutils_tarball}"
	tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"
fi

if ! [ -f "${gcc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz' --output-document="${gcc_tarball}"
	tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"
fi

while read file; do
	sed -i "s/-O2/${cflags}/g" "${file}"
done <<< "$(find '/tmp' -type 'f' -wholename '*configure')"

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

declare -r toolchain_directory="/tmp/unknown-unknown-netbsd"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs="$(nproc)"
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs="$(nproc)"
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs="$(nproc)"
make install

sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

declare -r targets=(
	'amd64'
	'i386'
	'emips'
	'alpha'
	'hppa'
	'sparc'
	'sparc64'
	'vax'
	'hpcsh'
	'evbppc'
)

for target in "${targets[@]}"; do
	declare url="https://cdn.netbsd.org/pub/NetBSD/NetBSD-8.0/${target}/binary/sets"
	
	case "${target}" in
		amd64)
			declare triple='x86_64-unknown-netbsd';;
		i386)
			declare triple='i386-unknown-netbsdelf';;
		emips)
			declare triple='mips-unknown-netbsd';;
		alpha)
			declare triple='alpha-unknown-netbsd';;
		hppa)
			declare triple='hppa-unknown-netbsd';;
		sparc)
			declare triple='sparc-unknown-netbsdelf';;
		sparc64)
			declare triple='sparc64-unknown-netbsd';;
		vax)
			declare triple='vax-unknown-netbsdelf';;
		hpcsh)
			declare triple='shle-unknown-netbsdelf';;
		evbppc)
			declare triple='powerpc-unknown-netbsd';;
	esac
	
	declare base_url="${url}/base.tgz"
	declare comp_url="${url}/comp.tgz"
	
	declare base_output="/tmp/$(basename "${base_url}")"
	declare comp_output="/tmp/$(basename "${comp_url}")"
	
	wget --no-verbose "${base_url}" --output-document="${base_output}"
	wget --no-verbose "${comp_url}" --output-document="${comp_output}"
	
	cd "${binutils_directory}/build"
	rm --force --recursive ./*
	
	../configure \
		--target="${triple}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld
	
	make all --jobs="$(nproc)"
	make install
	
	tar --directory="${toolchain_directory}/${triple}" --strip=2 --extract --file="${base_output}" './usr/lib' './usr/include'
	tar --directory="${toolchain_directory}/${triple}" --extract --file="${base_output}"  './lib'
	tar --directory="${toolchain_directory}/${triple}" --strip=2 --extract --file="${comp_output}" './usr/lib' './usr/include'
	
	cd "${gcc_directory}/build"
	
	rm --force --recursive ./*
	
	declare extra_configure_flags=''
	
	if [ "${target}" != 'hppa' ]; then
		extra_configure_flags+='--enable-gnu-unique-object '
	fi
	
	if [ "${target}" == 'emips' ]; then
		extra_configure_flags+='--with-float=soft '
	fi
	
	../configure \
		--target="${triple}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style='sysv' \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-system-zlib \
		--with-bugurl='https://github.com/AmanoTeam/n3tbsdcr0ss/issues' \
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
		--disable-multilib \
		--enable-plugin \
		--enable-shared \
		--enable-threads='posix' \
		--enable-libssp \
		--disable-libstdcxx-pch \
		--disable-werror \
		--enable-languages='c,c++' \
		--disable-bootstrap \
		--without-headers \
		--enable-ld \
		--enable-gold \
		--with-pic \
		--with-gcc-major-version-only \
		--with-pkgversion="n3tbsdcr0ss v0.1-${revision}" \
		--with-sysroot="${toolchain_directory}/${triple}" \
		--with-native-system-header-dir='/include' \
		${extra_configure_flags}
	
	LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make CFLAGS_FOR_TARGET="${cflags}" CXXFLAGS_FOR_TARGET="${cflags}" all --jobs="$(nproc)"
	make install
	
	rm --recursive "${toolchain_directory}/lib/gcc/${triple}/12/include-fixed"
done

tar --directory="$(dirname "${toolchain_directory}")" --create --file=- "$(basename "${toolchain_directory}")" |  xz --threads=0 --compress -9 > "${toolchain_tarball}"